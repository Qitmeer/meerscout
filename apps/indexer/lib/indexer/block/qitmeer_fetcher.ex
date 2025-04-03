defmodule Indexer.Block.QitmeerFetcher do
  @moduledoc """
  Fetches and indexes block ranges.
  """

  use Spandex.Decorators
  import Ecto.Query
  require Logger

  import Explorer.Chain.QitmeerBlock, only: [insert_block: 1]
  import Explorer.Chain.QitmeerStateRoot, only: [insert_stateroot: 1]
  import Explorer.Chain.QitmeerTransaction, only: [insert_tx: 1]
  alias EthereumJSONRPC.QitmeerBlocks
  alias Explorer.Chain.{QitmeerBlock, QitmeerTransaction, QitmeerSupply}
  alias Explorer.Repo
  alias Explorer.Chain.Qitmeer.{UTXORecord, QitmeerAccount}

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

    amount =
      case Map.fetch(out_index, "amount") do
        {:ok, _} -> out_index["amount"]
        :error -> 0
      end

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
      coinbase: amount,
      confirms: block_data["confirmations"],
      insert_catchup: insert_catchup
    }
  end

  defp save_blocks_to_db(blocks) do
    Enum.each(blocks, &insert_block/1)

    Enum.each(blocks, &import_supply/1)
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

    amount =
      case Map.fetch(out, "amount") do
        {:ok, _} -> out["amount"]
        :error -> 0
      end

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
          amount: amount,
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

  defp save_tx_to_db(txs) do
    Enum.each(txs, &insert_tx/1)
    Enum.each(txs, &handle_utxo_records/1)
  end

  def convert_and_save_tx_to_db(block_list) do
    block_list
    |> Enum.map(&convert_to_qitmeer_block_transaction/1)
  end

  defp save_stateroot(stateroot) do
    if not is_nil(stateroot["Order"]) do
      insert_stateroot(%{
        height: stateroot["Height"],
        evm_height: stateroot["EVMHeight"],
        hash: stateroot["Hash"],
        stateroot: stateroot["StateRoot"],
        evm_stateroot: stateroot["EVMStateRoot"],
        evm_head: stateroot["EVMHead"],
        block_order: stateroot["Order"],
        valid: stateroot["Valid"]
      })
    end

    :ok
  end

  defp handle_utxo_records(attrs) do
    # Convert amount to integer
    amount =
      case attrs.amount do
        %Decimal{} = decimal -> Decimal.to_integer(decimal)
        amount when is_integer(amount) -> amount
        amount when is_float(amount) -> round(amount)
        _ -> 0
      end

    case Repo.get_by(UTXORecord, tx_hash: attrs.hash, index: attrs.index) do
      nil ->
        # Create new UTXO record
        %UTXORecord{}
        |> UTXORecord.changeset(%{
          address: attrs.to_address,
          amount: amount,
          tx_hash: attrs.hash,
          index: attrs.index,
          spent: false,
          block_height: attrs.block_order
        })
        |> Repo.insert!()

        # Update account balance and utxo_count
        update_account_for_new_utxo(attrs.to_address, amount)

      _existing_record ->
        :ok
    end
  end

  defp handle_utxo_records(_), do: :ok

  def qitmeer_tx_update_status(tx_hash, index, insert_catchup) do
    # Update transaction status
    QitmeerTransaction.qitmeer_tx_update_status(tx_hash, index, insert_catchup)

    # Update UTXO spent status if transaction is spent
    case Repo.get_by(UTXORecord, tx_hash: tx_hash) do
      nil ->
        :ok

      record ->
        # Update UTXO spent status
        record
        |> UTXORecord.changeset(%{spent: true})
        |> Repo.update!()

        # Update account balance and tx_count
        update_account_for_spent_utxo(record.address, record.amount)
    end
  end

  defp update_account_for_new_utxo(address, amount) do
    case Repo.get(QitmeerAccount, address) do
      nil ->
        # Create new account
        %QitmeerAccount{}
        |> QitmeerAccount.changeset(%{
          address: address,
          balance: amount,
          tx_count: 0,
          utxo_count: 1
        })
        |> Repo.insert!()

      account ->
        # Update existing account
        account
        |> QitmeerAccount.changeset(%{
          balance: account.balance + amount,
          utxo_count: account.utxo_count + 1,
          tx_count: account.tx_count + 1
        })
        |> Repo.update!()
    end
  end

  defp update_account_for_spent_utxo(address, amount) do
    case Repo.get(QitmeerAccount, address) do
      nil ->
        :ok

      account ->
        # Update account balance and tx_count
        account
        |> QitmeerAccount.changeset(%{
          balance: account.balance - amount,
          tx_count: account.tx_count + 1
        })
        |> Repo.update!()
    end
  end

  def qng_fetch_and_import_range(
        %{
          json_rpc_named_arguments: json_rpc_named_arguments
        },
        range,
        insert_catchup
      ) do
    if not insert_catchup do
      case QitmeerJSONRPC.qng_fetch_block_stateroot(Enum.at(range, -1), json_rpc_named_arguments) do
        {:ok, %{"Order" => _o} = stateroot} ->
          save_stateroot(stateroot)

        {:error, _} ->
          IO.puts("Error fetching stateroot (range): #{inspect(range)}")
      end
    end

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

  defp import_supply(block_params) do
    total_supply = calculate_total_supply(block_params)
    latest_height = block_params.block_order
    latest_hash = block_params.hash
    timestamp = block_params.timestamp

    case Repo.one(from(s in QitmeerSupply, order_by: [desc: s.block_height], limit: 1)) do
      nil ->
        total_supply = calculate_total_supply(block_params)
        latest_height = block_params.block_order
        latest_hash = block_params.hash
        timestamp = block_params.timestamp

      supply ->
        latest_height = supply.block_height
        latest_hash = supply.block_hash
        timestamp = supply.timestamp
    end

    # Check if supply record exists
    latest_height =
      case Repo.get_by(QitmeerSupply,
             block_height: latest_height
           ) do
        nil ->
          # Insert new supply record
          %QitmeerSupply{}
          |> QitmeerSupply.changeset(%{
            total_supply: total_supply,
            block_height: latest_height,
            block_hash: latest_hash,
            timestamp: timestamp
          })
          |> Repo.insert!()

        existing_supply ->
          # Update existing supply record
          existing_supply
          |> QitmeerSupply.changeset(%{
            total_supply: total_supply,
            block_height: latest_height,
            block_hash: latest_hash,
            timestamp: timestamp
          })
          |> Repo.update!()
      end
  end

  defp calculate_total_supply(block_params) do
    # Get previous total supply
    previous_supply =
      case Repo.one(from(s in QitmeerSupply, order_by: [desc: s.block_height], limit: 1)) do
        nil -> Decimal.new(0)
        supply -> supply.total_supply
      end

    # Add coinbase amount to previous supply
    coinbase_amount = Decimal.new(block_params.coinbase || 0)

    Decimal.add(previous_supply, coinbase_amount)
  end
end
