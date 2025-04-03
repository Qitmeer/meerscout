defmodule EthereumJSONRPC.QitmeerPeerInfo do
  @moduledoc """
  Qitmeer peer info JSON-RPC methods.
  """

  @doc """
  Returns peer info for the specified peer ID.
  """
  def request(id) do
    EthereumJSONRPC.request(%{
      id: id,
      method: "qng_getPeerInfo",
      params: []
    })
  end

  @doc """
  Fetches peer info from the Qitmeer node
  """
  @spec fetch_peer_info(EthereumJSONRPC.json_rpc_named_arguments()) ::
          {:ok, [map()]} | {:error, reason :: term()}
  def fetch_peer_info(json_rpc_named_arguments) do
    request(0)
    |> EthereumJSONRPC.json_rpc(json_rpc_named_arguments)
  end
end
