defmodule QitmeerJSONRPC do
  @moduledoc """
  Qitmeer specific routines used to fetch and process
  data from the associated JSONRPC endpoint
  """
  require Logger
  import EthereumJSONRPC, only: [json_rpc: 2, id_to_params: 1]

  alias EthereumJSONRPC.{
    Blocks,
    QitmeerBlock,
    QitmeerBlocks
  }

  alias QitmeerBlock.{ByNumber, StateRoot}

  @doc """
  Fetches qng blocks by block number range.
  """
  def qng_fetch_blocks_by_range(range, json_rpc_named_arguments) do
    range
    |> Enum.map(fn number -> %{number: number} end)
    |> qng_fetch_blocks_by_params(&ByNumber.request/1, json_rpc_named_arguments)
  end

  def qng_fetch_block_stateroot(json_rpc_named_arguments) do
    %{id: 1}
    |> StateRoot.request()
    |> json_rpc(json_rpc_named_arguments)
  end

  def fetch_block_number_by_stateroot(json_rpc_named_arguments) do
    json_rpc_named_arguments
    |> qng_fetch_block_stateroot()
    |> StateRoot.number_from_result()
  end

  def qng_fetch_latest_block_number(json_rpc_named_arguments) do
    json_rpc_named_arguments
    |> qng_fetch_block_stateroot()
    |> StateRoot.order_from_result()
  end

  defp qng_fetch_blocks_by_params(params, request, json_rpc_named_arguments)
       when is_list(params) and is_function(request, 1) do
    id_to_params = id_to_params(params)

    with {:ok, responses} <-
           id_to_params
           |> Blocks.requests(request)
           |> json_rpc(json_rpc_named_arguments) do
      {:ok, QitmeerBlocks.qitmeer_from_responses(responses, id_to_params)}
    end
  end
end
