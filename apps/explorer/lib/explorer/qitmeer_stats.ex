defmodule Explorer.QitmeerStats do
  import Ecto.Query
  alias Explorer.Repo
  alias Explorer.Chain.{QitmeerBlock, QitmeerTransaction}
  alias Explorer.QitmeerDifficulty

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

  defp get_meer_total, do: 21_000_000
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
    # Get blocks from the last hour
    one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)

    # Query for blocks in the last hour
    blocks =
      Repo.all(
        from(b in QitmeerBlock,
          where: b.timestamp >= ^one_hour_ago,
          select: b.difficulty
        )
      )

    if Enum.empty?(blocks) do
      %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601(), hashrate: 0, difficulty: 0}
    else
      # Calculate average difficulty
      avg_difficulty = Enum.sum(blocks) / length(blocks)

      # Convert difficulty to target
      target = QitmeerDifficulty.compact_to_target(trunc(avg_difficulty))

      # Convert target to hashrate
      hashrate = QitmeerDifficulty.target_to_hashrate(target, calculate_average_block_time())

      # Format hashrate with appropriate unit
      {formatted_hashrate, unit} = QitmeerDifficulty.format_hashrate(hashrate)

      %{
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        hashrate: formatted_hashrate,
        difficulty: avg_difficulty,
        unit: unit
      }
    end
  end

  defp get_stats_by_day do
    # Get blocks from the last 24 hours
    one_day_ago = DateTime.add(DateTime.utc_now(), -86400, :second)

    # Query for blocks in the last 24 hours
    blocks =
      Repo.all(
        from(b in QitmeerBlock,
          where: b.timestamp >= ^one_day_ago,
          select: b.difficulty
        )
      )

    if Enum.empty?(blocks) do
      %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601(), hashrate: 0, difficulty: 0}
    else
      # Calculate average difficulty
      avg_difficulty = Enum.sum(blocks) / length(blocks)

      # Convert difficulty to target
      target = QitmeerDifficulty.compact_to_target(trunc(avg_difficulty))

      # Convert target to hashrate
      hashrate = QitmeerDifficulty.target_to_hashrate(target, calculate_average_block_time())

      # Format hashrate with appropriate unit
      {formatted_hashrate, unit} = QitmeerDifficulty.format_hashrate(hashrate)

      %{
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        hashrate: formatted_hashrate,
        difficulty: avg_difficulty,
        unit: unit
      }
    end
  end

  defp get_stats_by_week do
    # Get blocks from the last 7 days
    one_week_ago = DateTime.add(DateTime.utc_now(), -604_800, :second)

    # Query for blocks in the last 7 days
    blocks =
      Repo.all(
        from(b in QitmeerBlock,
          where: b.timestamp >= ^one_week_ago,
          select: b.difficulty
        )
      )

    if Enum.empty?(blocks) do
      %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601(), hashrate: 0, difficulty: 0}
    else
      # Calculate average difficulty
      avg_difficulty = Enum.sum(blocks) / length(blocks)

      # Convert difficulty to target
      target = QitmeerDifficulty.compact_to_target(trunc(avg_difficulty))

      # Convert target to hashrate
      hashrate = QitmeerDifficulty.target_to_hashrate(target, calculate_average_block_time())

      # Format hashrate with appropriate unit
      {formatted_hashrate, unit} = QitmeerDifficulty.format_hashrate(hashrate)

      %{
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        hashrate: formatted_hashrate,
        difficulty: avg_difficulty,
        unit: unit
      }
    end
  end
end
