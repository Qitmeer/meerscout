defmodule BlockScoutWeb.API.V2.QitmeerV2View do
  use BlockScoutWeb, :view

  def render("response.json", %{code: code, status: status, message: message, data: data}) do
    %{
      code: code,
      status: status,
      message: message,
      data: data
    }
  end

  def render("network_status.json", %{status: status}) do
    %{
      code: 200,
      status: "success",
      message: "ok",
      data: %{
        block_time: status.block_time,
        tx_rate: status.tx_rate,
        latest_block: status.latest_block,
        block_height: status.block_height,
        total_meer: status.total_meer,
        circulation: status.circulation
      }
    }
  end

  def render("hashrate_stats.json", %{stats: stats}) do
    %{
      code: 200,
      status: "success",
      message: "ok",
      data: %{
        timestamp: stats.timestamp,
        hashrate: stats.hashrate,
        difficulty: stats.difficulty
      }
    }
  end

  def render("accounts_list.json", %{accounts: accounts}) do
    %{
      code: 200,
      status: "success",
      message: "ok",
      data:
        Enum.map(accounts, fn account ->
          %{
            rank: account.rank,
            address: account.address,
            balance: account.balance,
            tx_count: account.tx_count,
            utxo_count: account.utxo_count
          }
        end)
    }
  end

  def render("utxo_address_info.json", %{info: info}) do
    %{
      code: 200,
      status: "success",
      message: "ok",
      data: %{
        balance: info.balance,
        utxos:
          Enum.map(info.utxos, fn utxo ->
            %{
              txid: utxo.txid,
              index: utxo.index,
              amount: utxo.amount,
              height: utxo.height
            }
          end)
      }
    }
  end

  def render("utxo_transactions.json", %{transactions: transactions}) do
    %{
      code: 200,
      status: "success",
      message: "ok",
      data:
        Enum.map(transactions, fn tx ->
          %{
            txid: tx.txid,
            amount: tx.amount,
            height: tx.height,
            timestamp: tx.timestamp
          }
        end)
    }
  end

  def render("node_status.json", %{nodes: nodes}) do
    %{
      code: 200,
      status: "success",
      message: "ok",
      data: %{
        total_nodes: nodes.total_nodes,
        active_nodes: nodes.active_nodes,
        peers:
          Enum.map(nodes.peers, fn peer ->
            %{
              id: peer.id,
              ip: peer.ip,
              port: peer.port,
              status: peer.status
            }
          end)
      }
    }
  end

  def render("error.json", %{code: code, message: message}) do
    %{
      code: code,
      status: "error",
      message: message,
      data: nil
    }
  end
end
