defmodule Explorer.QitmeerNodeStatus do
  @moduledoc """
  Module for handling Qitmeer node status information
  """
  alias EthereumJSONRPC.QitmeerPeerInfo

  @doc """
  Gets the status of all Qitmeer nodes
  """
  def get_all_nodes_status do
    case QitmeerPeerInfo.fetch_peer_info(transport_options()) do
      {:ok, peers} ->
        active_peers = Enum.filter(peers, & &1.active)

        %{
          total_nodes: length(peers),
          active_nodes: length(active_peers),
          peers:
            Enum.map(peers, fn peer ->
              %{
                id: peer.id,
                ip: extract_ip(peer.address),
                port: extract_port(peer.address),
                status: if(peer.active, do: "online", else: "offline")
              }
            end)
        }

      {:error, _reason} ->
        %{
          total_nodes: 0,
          active_nodes: 0,
          peers: []
        }
    end
  end

  defp transport_options do
    Application.get_env(:explorer, :json_rpc_named_arguments)
  end

  defp extract_ip(address) do
    case Regex.run(~r/\/ip4\/([^\/]+)/, address) do
      [_, ip] -> ip
      _ -> "unknown"
    end
  end

  defp extract_port(address) do
    case Regex.run(~r/\/tcp\/(\d+)/, address) do
      [_, port] -> String.to_integer(port)
      _ -> 0
    end
  end
end
