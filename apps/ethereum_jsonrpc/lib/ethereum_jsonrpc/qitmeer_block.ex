defmodule EthereumJSONRPC.QitmeerBlock do
  @moduledoc false
  @type elixir :: %{String.t() => non_neg_integer | DateTime.t() | String.t() | nil}
  @type params :: %{
          txs_valid: boolean(),
          difficulty: pos_integer(),
          hash: EthereumJSONRPC.hash(),
          miner_hash: String.t(),
          order: non_neg_integer(),
          height: non_neg_integer(),
          parent_root: EthereumJSONRPC.hash(),
          timestamp: DateTime.t(),
          pow: %{
            pow_name: String.t(),
            pow_type: non_neg_integer(),
            nonce: non_neg_integer()
          },
          transactions: [
            %{
              txid: EthereumJSONRPC.hash(),
              size: non_neg_integer(),
              lock_time: non_neg_integer(),
              txs_valid: boolean(),
              out_index: [
                %{
                  amount: non_neg_integer(),
                  scriptPubKey: %{
                    addresses: [String.t()]
                  }
                }
              ]
            }
          ]
        }

  @type t :: %{String.t() => EthereumJSONRPC.data() | EthereumJSONRPC.hash() | EthereumJSONRPC.quantity() | nil}

  def from_response(%{id: id, result: nil}, id_to_params) when is_map(id_to_params) do
    params = Map.fetch!(id_to_params, id)

    {:error, %{code: 404, message: "Not Found", data: params}}
  end

  def from_response(%{id: id, result: block}, id_to_params) when is_map(id_to_params) do
    true = Map.has_key?(id_to_params, id)

    {:ok, block}
  end

  def from_response(%{id: id, error: error}, id_to_params) when is_map(id_to_params) do
    params = Map.fetch!(id_to_params, id)
    annotated_error = Map.put(error, :data, params)

    {:error, annotated_error}
  end

  def elixir_to_params(%{
        txs_valid: txs_valid,
        difficulty: difficulty,
        hash: hash,
        order: order,
        height: height,
        parent_root: parent_root,
        timestamp: timestamp,
        pow: pow,
        transactions: transactions
      }) do
    coinbase = transactions |> List.first()
    out_index = hd(coinbase["vout"])
    miner = hd(out_index["scriptPubKey"]["addresses"])

    %{
      txs_valid: txs_valid,
      difficulty: difficulty,
      hash: hash,
      miner_hash: miner,
      nonce: Map.get(pow, "nonce", 0),
      order: order,
      height: height,
      parent_root: parent_root,
      timestamp: timestamp,
      pow: pow,
      transactions: transactions
    }
  end

  def elixir_to_transactions(%{"transactions" => transactions}), do: transactions

  def elixir_to_transactions(_), do: []

  def to_elixir(block) when is_map(block) do
    block
  end
end
