defmodule EthereumJSONRPC.QitmeerBlock.BlockCount do
  def request(json_rpc_named_arguments) do
    request_map = %{id: 1, method: "qng_getBlockCount", params: []}

    request_map
    |> EthereumJSONRPC.request()
    |> EthereumJSONRPC.json_rpc(json_rpc_named_arguments)
  end

  @moduledoc false
  def number_from_result({:ok, count}) do
    {:ok, count}
  end
end
