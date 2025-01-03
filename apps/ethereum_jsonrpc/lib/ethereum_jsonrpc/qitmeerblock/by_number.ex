defmodule EthereumJSONRPC.QitmeerBlock.ByNumber do
  @moduledoc """
  Block format as returned by [`qng_getBlockByOrder`]
  """

  def request(%{id: id, number: number}) do
    EthereumJSONRPC.request(%{id: id, method: "qng_getBlockByOrder", params: [number, true]})
  end
end
