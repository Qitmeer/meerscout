defmodule Explorer.QitmeerStats do
  import Ecto.Query
  alias Explorer.Repo
  alias Explorer.Chain.QitmeerBlock
  alias Explorer.Chain.QitmeerTransaction

  @doc """
    - block_time:
    - tx_rate:
    - latest_block:
    - block_height:
    - total_meer: MEER
    - circulation:
  """
  def get_network_status do
    latest_block = Repo.one(from(b in QitmeerBlock, order_by: [desc: b.height], limit: 1))

    if latest_block do
      status = %{
        block_time: calculate_average_block_time(),
        tx_rate: calculate_tx_rate(),
        latest_block: latest_block.block_order,
        block_height: latest_block.height,
        total_meer: get_meer_total(),
        circulation: get_circulating_supply()
      }

      {:ok, status}
    else
      {:ok,
       %{
         block_time: calculate_average_block_time(),
         tx_rate: calculate_tx_rate(),
         latest_block: 1,
         block_height: 1,
         total_meer: get_meer_total(),
         circulation: get_circulating_supply()
       }}
    end
  end

  #
  defp calculate_average_block_time, do: 15.0

  defp calculate_tx_rate do
    query =
      from(t in QitmeerTransaction,
        #
        where: t.tx_time > ^DateTime.from_unix!(System.system_time(:second) - 600, :second),
        select: count(t.hash)
      )

    total_txs = Repo.one(query) || 0
    #
    total_txs / 600
  end

  defp get_meer_total, do: 100_000_000
  defp get_circulating_supply, do: 80_000_000

  @doc """
  """
  def get_hashrate_stats(granularity) when granularity in ["hour", "day", "week"] do
    stats =
      case granularity do
        "hour" -> get_stats_by_hour()
        "day" -> get_stats_by_day()
        "week" -> get_stats_by_week()
      end

    {:ok, stats}
  end

  def get_hashrate_stats(_), do: {:error, :invalid_granularity}

  defp get_stats_by_hour do
    %{timestamp: "2025-03-23T01:00:00Z", hashrate: 5000, difficulty: 1_000_000}
  end

  defp get_stats_by_day do
    %{timestamp: "2025-03-22", hashrate: 120_000, difficulty: 25_000_000}
  end

  defp get_stats_by_week do
    %{timestamp: "2025-W12", hashrate: 850_000, difficulty: 150_000_000}
  end
end
