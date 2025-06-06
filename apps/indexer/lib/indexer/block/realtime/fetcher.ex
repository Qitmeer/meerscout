defmodule Indexer.Block.Realtime.Fetcher do
  @moduledoc """
  Fetches and indexes block ranges from latest block forward using a WebSocket.
  """

  use GenServer
  use Spandex.Decorators

  require Indexer.Tracer
  require Logger

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  import Indexer.Block.Fetcher,
    only: [
      async_import_blobs: 2,
      async_import_block_rewards: 2,
      async_import_celo_epoch_block_operations: 2,
      async_import_created_contract_codes: 2,
      async_import_filecoin_addresses_info: 2,
      async_import_internal_transactions: 2,
      async_import_polygon_zkevm_bridge_l1_tokens: 1,
      async_import_realtime_coin_balances: 1,
      async_import_replaced_transactions: 2,
      async_import_token_balances: 2,
      async_import_token_instances: 1,
      async_import_tokens: 2,
      async_import_uncles: 2,
      fetch_and_import_range: 2
    ]

  import Indexer.Block.QitmeerFetcher, only: [qng_fetch_and_import_range: 3]
  alias Ecto.Changeset
  alias EthereumJSONRPC.{Blocks, Subscription}
  alias Explorer.Chain
  alias Explorer.Chain.Cache.Counters.AverageBlockTime
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Utility.MissingRangesManipulator
  alias Indexer.{Block, Tracer}
  alias Indexer.Block.Realtime.TaskSupervisor
  alias Indexer.Prometheus
  alias Timex.Duration

  @behaviour Block.Fetcher

  @minimum_safe_polling_period :timer.seconds(1)

  @shutdown_after :timer.minutes(1)

  @enforce_keys ~w(block_fetcher)a

  defstruct block_fetcher: nil,
            subscription: nil,
            previous_number: nil,
            timer: nil,
            last_polled_hash: nil,
            qitmeer_previous_number: nil

  @type t :: %__MODULE__{
          block_fetcher: %Block.Fetcher{
            broadcast: term(),
            callback_module: __MODULE__,
            json_rpc_named_arguments: EthereumJSONRPC.json_rpc_named_arguments(),
            receipts_batch_size: pos_integer(),
            receipts_concurrency: pos_integer()
          },
          subscription: Subscription.t(),
          previous_number: pos_integer() | nil,
          timer: reference(),
          last_polled_hash: binary() | nil,
          qitmeer_previous_number: pos_integer() | nil
        }

  def start_link([arguments, gen_server_options]) do
    GenServer.start_link(__MODULE__, arguments, gen_server_options)
  end

  @impl GenServer
  def init(%{block_fetcher: %Block.Fetcher{} = block_fetcher, subscribe_named_arguments: subscribe_named_arguments}) do
    Logger.metadata(fetcher: :block_realtime)
    Process.flag(:trap_exit, true)

    {:ok, %__MODULE__{block_fetcher: %Block.Fetcher{block_fetcher | broadcast: :realtime, callback_module: __MODULE__}},
     {:continue, {:init, subscribe_named_arguments}}}
  end

  @impl GenServer
  def handle_continue({:init, subscribe_named_arguments}, %__MODULE__{subscription: nil} = state) do
    timer = schedule_polling()
    {:noreply, %__MODULE__{state | timer: timer} |> subscribe_to_new_heads(subscribe_named_arguments)}
  end

  # This handler catches blocks appeared in websocket (if WS is enabled).
  #
  # It takes into account the block hash which was lastly polled by the `:poll_latest_block_number` handler: if a block with
  # the same hash is already polled, the handler ignores it. Otherwise, the handler starts fetching and importing the block, and
  # schedules a new polling.
  #
  # ## Parameters
  # - `{subscription, {:ok, block}}` where `subscription` is an instance of WS subscription.
  # - `state` contains service parameters, also including:
  #   `previous_number` - the block number reported by the previous call.
  #   `timer` - the timer to call `:poll_latest_block_number` handler next time.
  #   `last_polled_hash` - the block hash which was polled by the `:poll_latest_block_number` handler on its previous call.
  #
  # ## Returns
  # - `{:noreply, state}` tuple where the `state` is the current or updated GenServer's state.
  @impl GenServer
  def handle_info(
        {subscription, {:ok, %{"number" => quantity, "hash" => hash}}},
        %__MODULE__{
          block_fetcher: %Block.Fetcher{} = block_fetcher,
          subscription: %Subscription{} = subscription,
          previous_number: previous_number,
          timer: timer,
          last_polled_hash: last_polled_hash,
          qitmeer_previous_number: qitmeer_previous_number
        } = state
      )
      when is_binary(quantity) do
    number = quantity_to_integer(quantity)

    if number > 0 do
      Publisher.broadcast([{:last_block_number, number}], :realtime)
    end

    if hash != last_polled_hash do
      Process.cancel_timer(timer)
      # Subscriptions don't support getting all the blocks and transactions data,
      # so we need to go back and get the full block
      start_fetch_and_import(number, block_fetcher, previous_number)
      start_qng_fetch_and_import(number, block_fetcher, qitmeer_previous_number)
      Process.cancel_timer(timer)

      new_timer = schedule_polling()

      {:noreply,
       %{
         state
         | previous_number: number,
           timer: new_timer
       }}
    else
      # The block from the websocket must be ignored if this block was already got by the `:poll_latest_block_number` handler
      {:noreply, state}
    end
  end

  # This handler gets the latest block using RPC request to get the latest block number.
  # It fetches the latest block number, starts its fetching and importing, and schedules the next polling iteration.
  #
  # ## Parameters
  # - `:poll_latest_block_number`: The message that triggers the fetching process.
  # - `state` contains service parameters, also including:
  #   `previous_number` - the block number reported by the previous block number fetching.
  #   `timer` - the timer to call this handler next time.
  #   `last_polled_hash` - the block hash which was polled by this handler on its previous call.
  #
  # ## Returns
  # - `{:noreply, state}` tuple where the `state` is the current or updated GenServer's state.
  #   Contains updated `previous_number`, `timer`, and `last_polled_hash` values.
  @impl GenServer
  def handle_info(
        :poll_latest_block_number,
        %__MODULE__{
          block_fetcher: %Block.Fetcher{json_rpc_named_arguments: json_rpc_named_arguments} = block_fetcher,
          previous_number: previous_number,
          qitmeer_previous_number: qitmeer_previous_number
        } = state
      ) do
    {new_previous_number, new_qitmeer_previous_number, new_last_polled_hash} =
      case QitmeerJSONRPC.qng_fetch_block_stateroot(-1, json_rpc_named_arguments) do
        {:ok, %{"Order" => block_order, "EVMHeight" => evm_height, "EVMStateRoot" => new_hash} = stateroot} ->
          temp_new_previous_number =
            case evm_height do
              number when is_nil(previous_number) or number != previous_number ->
                number =
                  if abnormal_gap?(number, previous_number) do
                    new_number = max(number, previous_number)
                    start_fetch_and_import(new_number, block_fetcher, previous_number)
                    new_number
                  else
                    start_fetch_and_import(number, block_fetcher, previous_number)
                    number
                  end

                fetch_validators_async()
                number

              _ ->
                previous_number
            end

          temp_new_qitmeer_previous_number =
            case block_order do
              number when is_nil(qitmeer_previous_number) or number > qitmeer_previous_number ->
                if abnormal_gap?(number, qitmeer_previous_number) do
                  new_number = max(number, qitmeer_previous_number)

                  if QitmeerStateroot.check_stateroot(stateroot, qitmeer_previous_number) do
                    start_qng_fetch_and_import(new_number, block_fetcher, qitmeer_previous_number)
                  else
                    reorg_start = number - Application.get_env(:indexer, __MODULE__)[:max_gap] || @default_max_gap
                    reorg_start = max(reorg_start, 0)
                    start_qng_fetch_and_import(new_number, block_fetcher, reorg_start)
                  end

                  new_number
                else
                  start_qng_fetch_and_import(number, block_fetcher, qitmeer_previous_number)
                  number
                end

              _ ->
                qitmeer_previous_number
            end

          case block_order do
            number when is_nil(qitmeer_previous_number) or number <= qitmeer_previous_number ->
              reorg_start = number - Application.get_env(:indexer, __MODULE__)[:max_gap] || @default_max_gap
              reorg_start = max(reorg_start, 0)
              new_number = max(number, reorg_start)
              start_qng_fetch_and_import(new_number, block_fetcher, reorg_start)
              number

            _ ->
              qitmeer_previous_number
          end

          {temp_new_previous_number, temp_new_qitmeer_previous_number, new_hash}

        other ->
          IO.puts("Error fetching stateroot: #{inspect(other)}")
          {previous_number, qitmeer_previous_number}
      end

    timer = schedule_polling()

    {:noreply,
     %{
       state
       | previous_number: new_previous_number,
         timer: timer,
         last_polled_hash: new_last_polled_hash,
         qitmeer_previous_number: new_qitmeer_previous_number
     }}
  end

  # don't handle other messages (e.g. :ssl_closed)
  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, %__MODULE__{timer: timer}) do
    Process.cancel_timer(timer)
  end

  defp fetch_validators_async do
    chain_type = Application.get_env(:explorer, :chain_type)
    do_fetch_validators_async(chain_type)
  end

  defp do_fetch_validators_async(:stability) do
    alias Indexer.Fetcher.Stability.Validator, as: StabilityValidator

    StabilityValidator.trigger_update_validators_list()
  end

  defp do_fetch_validators_async(:blackfort) do
    alias Indexer.Fetcher.Blackfort.Validator, as: BlackfortValidator

    BlackfortValidator.trigger_update_validators_list()
  end

  defp do_fetch_validators_async(_chain_type) do
    :ignore
  end

  defp subscribe_to_new_heads(%__MODULE__{subscription: nil} = state, subscribe_named_arguments)
       when is_list(subscribe_named_arguments) do
    case EthereumJSONRPC.subscribe("newHeads", subscribe_named_arguments) do
      {:ok, subscription} ->
        %__MODULE__{state | subscription: subscription}

      {:error, reason} ->
        Logger.debug(fn -> ["Could not connect to websocket: #{inspect(reason)}. Continuing with polling."] end)
        state
    end
  catch
    :exit, _reason ->
      if Map.get(state, :timer) && state.timer do
        Process.cancel_timer(state.timer)
      end

      timer = schedule_polling()
      %{state | timer: timer}
  end

  defp subscribe_to_new_heads(state, _), do: state

  defp schedule_polling do
    polling_period =
      case Application.get_env(:indexer, __MODULE__)[:polling_period] do
        nil ->
          case AverageBlockTime.average_block_time() do
            {:error, :disabled} -> 2_000
            block_time -> min(round(Duration.to_milliseconds(block_time) / 2), 30_000)
          end

        period ->
          period
      end

    safe_polling_period = max(polling_period, @minimum_safe_polling_period)

    Process.send_after(self(), :poll_latest_block_number, safe_polling_period)
  end

  @import_options ~w(address_hash_to_fetched_balance_block_number)a

  @impl Block.Fetcher
  def import(_block_fetcher, %{block_rewards: block_rewards} = options) do
    {block_reward_errors, chain_import_block_rewards} = Map.pop(block_rewards, :errors)

    chain_import_options =
      options
      |> Map.drop(@import_options)
      |> put_in([:blocks, :params, Access.all(), :consensus], true)
      |> put_in([:blocks, :params, Access.all(), :refetch_needed], false)
      |> put_in([:block_rewards], chain_import_block_rewards)

    with {:import, {:ok, imported} = ok} <- {:import, Chain.import(chain_import_options)} do
      async_import_remaining_block_data(
        imported,
        %{block_rewards: %{errors: block_reward_errors}}
      )

      ok
    end
  end

  def import(_, _) do
    Logger.warning("Empty parameters were provided for realtime fetcher")

    {:ok, []}
  end

  def start_fetch_and_import(number, block_fetcher, previous_number) do
    start_at = determine_start_at(number, previous_number)
    is_reorg = reorg?(number, previous_number)

    for block_number_to_fetch <- start_at..number do
      args = [block_number_to_fetch, block_fetcher, is_reorg]
      Task.Supervisor.start_child(TaskSupervisor, __MODULE__, :fetch_and_import_block, args, shutdown: @shutdown_after)
    end
  end

  defp determine_start_at(number, nil), do: number

  defp determine_start_at(number, previous_number) do
    if reorg?(number, previous_number) do
      # set start_at to NOT fill in skipped numbers
      number
    else
      # set start_at to fill in skipped numbers, if any
      previous_number + 1
    end
  end

  defp reorg?(number, previous_number) when is_integer(previous_number) and number <= previous_number do
    true
  end

  defp reorg?(_, _), do: false

  @default_max_gap 1000
  defp abnormal_gap?(_number, nil), do: false

  defp abnormal_gap?(number, previous_number) do
    max_gap = Application.get_env(:indexer, __MODULE__)[:max_gap] || @default_max_gap

    abs(number - previous_number) > max_gap
  end

  @reorg_delay 5_000

  @decorate trace(name: "fetch", resource: "Indexer.Block.Realtime.Fetcher.fetch_and_import_block/3", tracer: Tracer)
  def fetch_and_import_block(block_number_to_fetch, block_fetcher, reorg?, retry \\ 3) do
    Process.flag(:trap_exit, true)

    Indexer.Logger.metadata(
      fn ->
        if reorg? do
          remove_assets_by_number(block_number_to_fetch)

          # give previous fetch attempt (for same block number) a chance to finish
          # before fetching again, to reduce block consensus mistakes
          :timer.sleep(@reorg_delay)
        end

        do_fetch_and_import_block(block_number_to_fetch, block_fetcher, retry)
      end,
      fetcher: :block_realtime,
      block_number: block_number_to_fetch
    )
  end

  @spec remove_assets_by_number(non_neg_integer()) :: any()
  defp remove_assets_by_number(reorg_block) do
    chain_type = Application.get_env(:explorer, :chain_type)
    do_remove_assets_by_number(chain_type, reorg_block)
  end

  # Removes all rows from `op_transaction_batches`, `op_withdrawals`,
  # and `op_eip1559_config_updates` tables previously written starting
  # from the reorg block number
  defp do_remove_assets_by_number(:optimism, reorg_block) do
    # credo:disable-for-lines:3 Credo.Check.Design.AliasUsage
    Indexer.Fetcher.Optimism.EIP1559ConfigUpdate.handle_realtime_l2_reorg(reorg_block)
    Indexer.Fetcher.Optimism.TransactionBatch.handle_l2_reorg(reorg_block)
    Indexer.Fetcher.Optimism.Withdrawal.remove(reorg_block)
  end

  # Removes all rows from `polygon_edge_withdrawals` and `polygon_edge_deposit_executes` tables
  # previously written starting from the reorg block number
  defp do_remove_assets_by_number(:polygon_edge, reorg_block) do
    # credo:disable-for-lines:2 Credo.Check.Design.AliasUsage
    Indexer.Fetcher.PolygonEdge.Withdrawal.remove(reorg_block)
    Indexer.Fetcher.PolygonEdge.DepositExecute.remove(reorg_block)
  end

  # Removes all rows from `polygon_zkevm_bridge` table
  # previously written starting from the reorg block number
  defp do_remove_assets_by_number(:polygon_zkevm, reorg_block) do
    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    Indexer.Fetcher.PolygonZkevm.BridgeL2.reorg_handle(reorg_block)
  end

  # Removes all rows from `shibarium_bridge` table
  # previously written starting from the reorg block number
  defp do_remove_assets_by_number(:shibarium, reorg_block) do
    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    Indexer.Fetcher.Shibarium.L2.reorg_handle(reorg_block)
  end

  # Removes all rows from `scroll_bridge` and `scroll_l1_fee_params` tables
  # previously written starting from the reorg block number
  defp do_remove_assets_by_number(:scroll, reorg_block) do
    # credo:disable-for-lines:2 Credo.Check.Design.AliasUsage
    Indexer.Fetcher.Scroll.BridgeL2.reorg_handle(reorg_block)
    Indexer.Fetcher.Scroll.L1FeeParam.handle_l2_reorg(reorg_block)
  end

  defp do_remove_assets_by_number(_, _), do: :ok

  @decorate span(tracer: Tracer)
  defp do_fetch_and_import_block(block_number_to_fetch, block_fetcher, retry) do
    time_before = Timex.now()

    {fetch_duration, result} =
      :timer.tc(fn -> fetch_and_import_range(block_fetcher, block_number_to_fetch..block_number_to_fetch) end)

    Prometheus.Instrumenter.block_full_process(fetch_duration, __MODULE__)

    case result do
      {:ok, %{inserted: inserted, errors: []}} ->
        log_import_timings(inserted, fetch_duration, time_before)
        MissingRangesManipulator.clear_batch([block_number_to_fetch..block_number_to_fetch])
        Logger.debug("Fetched and imported.")

      {:ok, %{inserted: _, errors: [_ | _] = errors}} ->
        Logger.error(fn ->
          [
            "failed to fetch block: ",
            inspect(errors),
            ".  Block will be retried by catchup indexer."
          ]
        end)

      {:error, {:import = step, [%Changeset{} | _] = changesets}} ->
        Prometheus.Instrumenter.import_errors()

        params = %{
          changesets: changesets,
          block_number_to_fetch: block_number_to_fetch,
          block_fetcher: block_fetcher,
          retry: retry
        }

        if retry_fetch_and_import_block(params) == :ignore do
          Logger.error(
            fn ->
              [
                "failed to validate for block ",
                to_string(block_number_to_fetch),
                ": ",
                inspect(changesets),
                ".  Block will be retried by catchup indexer."
              ]
            end,
            step: step
          )
        end

      {:error, {:import = step, reason}} ->
        Prometheus.Instrumenter.import_errors()
        Logger.error(fn -> inspect(reason) end, step: step)

      {:error, {step, reason}} ->
        Logger.error(
          fn ->
            [
              "failed to fetch: ",
              inspect(reason),
              ".  Block will be retried by catchup indexer."
            ]
          end,
          step: step
        )

      {:error, {step, failed_value, _changes_so_far}} ->
        Logger.error(
          fn ->
            [
              "failed to insert: ",
              inspect(failed_value),
              ".  Block will be retried by catchup indexer."
            ]
          end,
          step: step
        )
    end
  end

  defp log_import_timings(%{blocks: [%{number: number, timestamp: timestamp}]}, fetch_duration, time_before) do
    node_delay = Timex.diff(time_before, timestamp, :seconds)
    Prometheus.Instrumenter.node_delay(node_delay)

    Logger.debug("Block #{number} fetching duration: #{fetch_duration / 1_000_000}s. Node delay: #{node_delay}s.",
      fetcher: :block_import_timings
    )
  end

  defp log_import_timings(_inserted, _duration, _time_before), do: nil

  defp retry_fetch_and_import_block(%{retry: retry}) when retry < 1, do: :ignore

  defp retry_fetch_and_import_block(%{changesets: changesets} = params) do
    if unknown_block_number_error?(changesets) do
      # Wait half a second to give Nethermind time to sync.
      :timer.sleep(500)

      number = params.block_number_to_fetch
      fetcher = params.block_fetcher
      updated_retry = params.retry - 1

      do_fetch_and_import_block(number, fetcher, updated_retry)
    else
      :ignore
    end
  end

  defp unknown_block_number_error?(changesets) do
    Enum.any?(changesets, &(Map.get(&1, :message) == "Unknown block number"))
  end

  defp async_import_remaining_block_data(
         imported,
         %{block_rewards: %{errors: block_reward_errors}}
       ) do
    realtime? = true

    async_import_realtime_coin_balances(imported)
    async_import_block_rewards(block_reward_errors, realtime?)
    async_import_created_contract_codes(imported, realtime?)
    async_import_internal_transactions(imported, realtime?)
    async_import_tokens(imported, realtime?)
    async_import_token_balances(imported, realtime?)
    async_import_token_instances(imported)
    async_import_uncles(imported, realtime?)
    async_import_replaced_transactions(imported, realtime?)
    async_import_blobs(imported, realtime?)
    async_import_polygon_zkevm_bridge_l1_tokens(imported)
    async_import_celo_epoch_block_operations(imported, realtime?)
    async_import_filecoin_addresses_info(imported, realtime?)
  end

  def start_qng_fetch_and_import(number, block_fetcher, previous_number) do
    start_at = determine_start_at(number, previous_number)
    is_reorg = reorg?(number, previous_number)

    for block_number_to_fetch <- start_at..number do
      args = [block_number_to_fetch, block_fetcher, is_reorg]

      Task.Supervisor.start_child(TaskSupervisor, __MODULE__, :qng_fetch_and_import_block, args,
        shutdown: @shutdown_after
      )
    end
  end

  @decorate trace(
              name: "fetch",
              resource: "Indexer.Block.Realtime.Fetcher.qng_fetch_and_import_block/3",
              tracer: Tracer
            )
  def qng_fetch_and_import_block(block_number_to_fetch, block_fetcher, reorg?, retry \\ 3) do
    Process.flag(:trap_exit, true)

    Indexer.Logger.metadata(
      fn ->
        if reorg? do
          # give previous fetch attempt (for same block number) a chance to finish
          # before fetching again, to reduce block consensus mistakes
          :timer.sleep(@reorg_delay)
        end

        qng_do_fetch_and_import_block(block_number_to_fetch, block_fetcher, retry)
      end,
      fetcher: :block_realtime,
      block_number: block_number_to_fetch
    )
  end

  @decorate span(tracer: Tracer)
  defp qng_do_fetch_and_import_block(block_number_to_fetch, block_fetcher, _retry) do
    # time_before = Timex.now()

    :timer.tc(fn -> qng_fetch_and_import_range(block_fetcher, block_number_to_fetch..block_number_to_fetch, false) end)

    # Prometheus.Instrumenter.block_full_process(fetch_duration, __MODULE__)
    # Logger.debug("record Fetched Failed and retry.")
  end
end
