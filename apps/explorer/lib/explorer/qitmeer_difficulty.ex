defmodule Explorer.QitmeerDifficulty do
  @moduledoc """
  Module for handling Qitmeer difficulty calculations and conversions
  """

  @max_target "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

  @doc """
  Converts compact difficulty to target
  """
  def compact_to_target(compact) when is_integer(compact) do
    # Extract the mantissa, sign bit, and exponent
    mantissa = Bitwise.band(compact, 0x007FFFFF)
    is_negative = Bitwise.band(compact, 0x00800000) != 0
    exponent = Bitwise.bsr(compact, 24)

    # Calculate target based on exponent
    target =
      if exponent <= 3 do
        Bitwise.bsr(mantissa, 8 * (3 - exponent))
      else
        Bitwise.bsl(mantissa, 8 * (exponent - 3))
      end

    # Make it negative if the sign bit is set
    if is_negative, do: -target, else: target
  end

  @doc """
  Converts target to hashrate
  """
  def target_to_hashrate(target, block_time) do
    max_target = String.to_integer(@max_target, 16)
    hashrate = div(max_target, target)
    div(hashrate, block_time)
  end

  @doc """
  Formats hashrate with appropriate unit
  """
  def format_hashrate(hashrate) do
    cond do
      hashrate < 1000 -> {hashrate, "H/s"}
      hashrate < 1_000_000 -> {hashrate / 1000, "KH/s"}
      hashrate < 1_000_000_000 -> {hashrate / 1_000_000, "MH/s"}
      hashrate < 1_000_000_000_000 -> {hashrate / 1_000_000_000, "GH/s"}
      hashrate < 1_000_000_000_000_000 -> {hashrate / 1_000_000_000_000, "TH/s"}
      hashrate < 1_000_000_000_000_000_000 -> {hashrate / 1_000_000_000_000_000, "PH/s"}
      true -> {hashrate / 1_000_000_000_000_000_000, "EH/s"}
    end
  end
end
