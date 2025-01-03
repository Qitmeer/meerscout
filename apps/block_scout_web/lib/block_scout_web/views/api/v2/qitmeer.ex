defmodule BlockScoutWeb.API.V2.QitmeerView do
  use BlockScoutWeb, :view
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias Explorer.Chain.QitmeerTransaction

  def render("qitmeer_address.json", %{addr_info: addr_info}) do
    prepare_qitmeer_address(addr_info)
  end

  def prepare_qitmeer_address(addr_info) do
    %{
      "address" => addr_info.address,
      "available" => addr_info.available,
      "spent" => addr_info.spent,
      "unavailable" => addr_info.unavailable
    }
  end

  def render("qitmeer_blocks.json", %{blocks: blocks, next_page_params: next_page_params}) do
    %{"items" => Enum.map(blocks, &prepare_qitmeer_block(&1, nil)), "next_page_params" => next_page_params}
  end

  def render("qitmeer_block.json", %{block: block}) do
    prepare_qitmeer_block(block, true)
  end

  def prepare_qitmeer_block(block, _single_block? \\ false) do
    %{
      "block_order" => block.block_order,
      "height" => block.height,
      "timestamp" => block.timestamp,
      "tx_count" => block.txns,
      "miner_hash" => block.miner_hash,
      "hash" => block.hash,
      "parent_root" => block.parent_root,
      "difficulty" => block.difficulty,
      "pow_name" => block.pow_name,
      "txs_valid" => block.txs_valid,
      "nonce" => block.nonce,
      "confirms" => block.confirms,
      "weight" => block.weight
    }
  end

  def render("qitmeer_transactions.json", %{transactions: transactions, next_page_params: next_page_params}) do
    %{
      "items" =>
        transactions
        |> Enum.map(fn tx -> prepare_qitmeer_transaction(tx, false) end),
      "next_page_params" => next_page_params
    }
  end

  def render("qitmeer_transaction.json", %{transaction: transaction}) do
    prepare_qitmeer_transaction(transaction, true)
  end

  defp prepare_qitmeer_transaction(
         %QitmeerTransaction{} = tx,
         _single_tx?
       ) do
    %{
      "block_hash" => tx.block_hash,
      "block_order" => tx.block_order,
      "hash" => tx.hash,
      "tx_time" => tx.tx_time,
      "size" => tx.size,
      "tx_index" => tx.tx_index,
      "to_address" => tx.to_address,
      "spent_tx_hash" => tx.spent_tx_hash,
      "amount" => tx.amount
    }
  end
end
