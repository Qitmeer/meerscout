defmodule Indexer.Block.QitmeerCatchup.Fetcher do
  @moduledoc """
  Fetches and indexes block ranges from the block before the latest block to genesis (0) that are missing.
  """

  use Spandex.Decorators

  require Logger

  import Indexer.Block.QitmeerFetcher, only: [qng_fetch_and_import_range: 3]
  import Explorer.Chain.QitmeerBlock, only: [fetch_min_max: 0]
  alias Indexer.Block

  @behaviour Block.Fetcher

  defstruct block_fetcher: nil,
            memory_monitor: nil

  @impl Block.Fetcher
  def import(_block_fetcher, options) when is_map(options) do
    # db handle
    :ok
  end

  @doc """
  Required named arguments
    * `:json_rpc_named_arguments` - `t:EthereumJSONRPC.json_rpc_named_arguments/0` passed to
        `EthereumJSONRPC.json_rpc/2`.
  """
  def task(state) do
    Logger.metadata(fetcher: :block_catchup)
    fetch_and_import_range_from_min(state)
  end

  defp fetch_and_import_range_from_min(%__MODULE__{block_fetcher: %Block.Fetcher{} = block_fetcher} = state) do
    case fetch_min_max() do
      %{min: nil, max: nil} ->
        min = 0
        max_value = 1000
        range = min..max_value
        Logger.info(fn -> "init Qitmeer Blocks Fetching range #{inspect(range)}" end, fetcher: :block_catchup)
        :timer.tc(fn -> qng_fetch_and_import_range(block_fetcher, range, true) end)

      %{min: _min, max: dbmax} ->
        min = dbmax + 1

        max_value = min + 1000

        range = min..max_value
        Logger.info(fn -> "Qitmeer Blocks Fetching range #{inspect(range)}" end, fetcher: :block_catchup)
        :timer.tc(fn -> qng_fetch_and_import_range(block_fetcher, range, true) end)
    end

    {:ok, state}
  end
end
