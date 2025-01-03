defmodule EthereumJSONRPC.QitmeerBlock.ByHash do
  @moduledoc """
  Block format as returned by [`qng_getBlock`]
  """

  @include_transactions true

  def request(%{id: id, hash: hash}) do
    EthereumJSONRPC.request(%{id: id, method: "qng_getBlock", params: [hash, @include_transactions]})
  end
end
