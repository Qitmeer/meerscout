defmodule EthereumJSONRPC.QitmeerBlock.StateRoot do
  @moduledoc """
  Block format as returned by [`qng_getStateRoot`]
  """

  def request(%{id: id}) do
    EthereumJSONRPC.request(%{id: id, method: "qng_getStateRoot", params: [-1, true]})
  end

  def number_from_result({:ok, %{"EVMHeight" => quantity}}) do
    {:ok, quantity}
  end

  def order_from_result({:ok, %{"Order" => quantity}}) do
    {:ok, quantity}
  end
end
