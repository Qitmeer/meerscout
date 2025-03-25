defmodule BlockScoutWeb.API.V2.QitmeerV2Controller do
  use BlockScoutWeb, :controller

  alias Explorer.QitmeerStats
  alias Explorer.QitmeerAccounts
  alias Explorer.QitmeerUTXO
  alias Explorer.QitmeerNodeStatus
  alias BlockScoutWeb.Api.V2.QitmeerV2View

  def network_status(conn, _params) do
    with {:ok, status} <- QitmeerStats.get_network_status() do
      render(conn, "network_status.json", status: status)
    else
      _ -> render(conn, "error.json", error: "Internal Server Error")
    end
  end

  def hashrate_stats(conn, _params) do
    query_params = conn.query_params

    period = Map.get(query_params, "period", "hour")

    with {:ok, stats} <- QitmeerStats.get_hashrate_stats(period) do
      render(conn, "hashrate_stats.json", stats: stats)
    else
      _ -> render(conn, "error.json", error: "Invalid period parameter")
    end
  end

  def accounts_list(conn, params) do
    accounts = QitmeerAccounts.list_sorted_accounts(params)
    render(conn, "accounts_list.json", accounts: accounts)
  end

  def utxo_address_info(conn, %{"address" => address}) do
    case QitmeerUTXO.get_address_info(address) do
      nil ->
        render(conn, "error.json", error: "Address not found")

      info ->
        render(conn, "utxo_address_info.json", info: info)
    end
  end

  def utxo_transactions(conn, %{"address" => address} = params) do
    txs = QitmeerUTXO.get_transactions_by_address(address, params)
    render(conn, "utxo_transactions.json", transactions: txs)
  end

  def node_status(conn, _params) do
    nodes = QitmeerNodeStatus.get_all_nodes_status()
    render(conn, "node_status.json", nodes: nodes)
  end
end
