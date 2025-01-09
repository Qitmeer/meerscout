defmodule Indexer.Block.QitmeerFetcher do
  @moduledoc """
  Fetches and indexes block ranges.
  """

  use Spandex.Decorators

  require Logger

  import Explorer.Chain.QitmeerBlock, only: [insert_block: 1]
  import Explorer.Chain.QitmeerTransaction, only: [insert_tx: 1, qitmeer_tx_update_status: 3]
  alias EthereumJSONRPC.QitmeerBlocks

  @type t :: %__MODULE__{}

  # These are all the *default* values for options.
  # DO NOT use them directly in the code.  Get options from `state`.

  @receipts_batch_size 250
  @receipts_concurrency 10

  @doc false
  def default_receipts_batch_size, do: @receipts_batch_size

  @doc false
  def default_receipts_concurrency, do: @receipts_concurrency

  @enforce_keys ~w(json_rpc_named_arguments)a
  defstruct broadcast: nil,
            callback_module: nil,
            json_rpc_named_arguments: nil,
            receipts_batch_size: @receipts_batch_size,
            receipts_concurrency: @receipts_concurrency

  defp convert_to_qitmeer_block(block_data, insert_catchup) do
    coinbase = block_data["transactions"] |> List.first()
    out_index = hd(coinbase["vout"])
    script = out_index["scriptPubKey"]

    %{
      block_order: block_data["order"],
      height: block_data["height"],
      weight: block_data["weight"],
      txs_valid: block_data["txsvalid"],
      miner_hash: hd(script["addresses"]),
      hash: block_data["hash"],
      parent_root: block_data["parentroot"],
      timestamp: block_data["timestamp"],
      nonce: block_data["pow"] |> Map.get("nonce"),
      pow_name: block_data["pow"] |> Map.get("pow_name"),
      difficulty: block_data["difficulty"],
      txns: length(block_data["transactions"]),
      coinbase: out_index["amount"],
      confirms: block_data["confirmations"],
      insert_catchup: insert_catchup
    }
  end

  defp save_blocks_to_db(blocks) do
    Enum.each(blocks, &insert_block/1)
  end

  def convert_and_save_to_db(block_list, insert_catchup) do
    block_list
    |> Enum.map(fn block -> convert_to_qitmeer_block(block, insert_catchup) end)
    |> save_blocks_to_db()
  end

  defp process_vin(vin, tx_data) do
    case Map.fetch(vin, "txid") do
      {:ok, txid} ->
        qitmeer_tx_update_status(txid, vin["vout"], tx_data["txid"])
        "#{txid}:#{vin["vout"]}"

      :error ->
        "coinbase:#{vin["coinbase"]}"
    end
  end

  defp convert_to_qitmeer_transaction_out(out, index, tx_index, tx_data, block_order, block_hash) do
    script = out["scriptPubKey"]

    case Map.fetch(script, "addresses") do
      {:ok, _} ->
        addr = hd(script["addresses"])

        vins =
          tx_data["vin"]
          |> Enum.map_join(",", &process_vin(&1, tx_data))

        %{
          block_order: block_order,
          block_hash: block_hash,
          size: tx_data["size"],
          tx_index: tx_index,
          index: index,
          hash: tx_data["txid"],
          lock_time: tx_data["locktime"],
          to_address: addr,
          amount: out["amount"],
          fee: 0,
          tx_time: tx_data["timestamp"],
          vin: vins,
          pk_script: out["scriptPubKey"]["hex"],
          status: 1
        }

      :error ->
        %{
          :error => "no addresses"
        }
    end
  end

  defp convert_to_qitmeer_transaction(tx_data, tx_index, block_order, block_hash) do
    tx_data["vout"]
    |> Enum.with_index()
    |> Enum.map(fn {out, index} ->
      convert_to_qitmeer_transaction_out(out, index, tx_index, tx_data, block_order, block_hash)
    end)
  end

  defp convert_to_qitmeer_block_transaction(block_data) do
    block_data["transactions"]
    |> Enum.with_index()
    |> Enum.each(fn {transaction, index} ->
      transaction
      |> convert_to_qitmeer_transaction(index, block_data["order"], block_data["hash"])
      |> save_tx_to_db()
    end)
  end

  defp save_tx_to_db(blocks) do
    Enum.each(blocks, &insert_tx/1)
  end

  def convert_and_save_tx_to_db(block_list) do
    block_list
    |> Enum.map(&convert_to_qitmeer_block_transaction/1)
  end

  def qng_fetch_and_import_range(
        %{
          json_rpc_named_arguments: json_rpc_named_arguments
        },
        range,
        insert_catchup
      ) do
    {_, fetched_blocks} =
      :timer.tc(fn -> QitmeerJSONRPC.qng_fetch_blocks_by_range(range, json_rpc_named_arguments) end)

    case fetched_blocks do
      {:ok, %QitmeerBlocks{blocks_params: blocks_params}} ->
        convert_and_save_to_db(blocks_params, insert_catchup)
        convert_and_save_tx_to_db(blocks_params)

      _ ->
        []
    end

    {:ok}
  end
end
