defmodule Explorer.QitmeerNodeStatus do
  @doc """
  """
  def get_all_nodes_status do
    %{
      total_nodes: 2,
      active_nodes: 1,
      peers: [
        %{id: "node1", ip: "192.168.1.1", port: 30303, status: "online"},
        %{id: "node2", ip: "192.168.1.2", port: 30303, status: "offline"}
      ]
    }
  end
end
