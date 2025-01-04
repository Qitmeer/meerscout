defmodule EthereumJSONRPC.QitmeerBlocks do
  @moduledoc """
  Blocks format as returned by [`eth_getBlockByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC/e8e0771b9f3677693649d945956bc60e886ceb2b#eth_getblockbyhash)
  and [`eth_getBlockByNumber`](https://github.com/ethereum/wiki/wiki/JSON-RPC/e8e0771b9f3677693649d945956bc60e886ceb2b#eth_getblockbynumber) from batch requests.
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias EthereumJSONRPC.{Block, QitmeerBlock}

  @type elixir :: [Block.elixir()]
  @type params :: [Block.params()]

  @default_struct_fields [
    blocks_params: [],
    block_second_degree_relations_params: [],
    transactions_params: [],
    withdrawals_params: [],
    errors: []
  ]

  case @chain_type do
    :zilliqa ->
      @chain_type_fields quote(
                           do: [
                             zilliqa_quorum_certificates_params: [
                               EthereumJSONRPC.Zilliqa.QuorumCertificate.params()
                             ],
                             zilliqa_aggregate_quorum_certificates_params: [
                               EthereumJSONRPC.Zilliqa.AggregateQuorumCertificate.params()
                             ],
                             zilliqa_nested_quorum_certificates_params: [
                               EthereumJSONRPC.Zilliqa.NestedQuorumCertificates.params()
                             ]
                           ]
                         )

      @chain_type_struct_fields [
        zilliqa_quorum_certificates_params: [],
        zilliqa_aggregate_quorum_certificates_params: [],
        zilliqa_nested_quorum_certificates_params: []
      ]

    _ ->
      @chain_type_struct_fields []
      @chain_type_fields quote(do: [])
  end

  @type t :: %__MODULE__{
          unquote_splicing(@chain_type_fields),
          blocks_params: [map()],
          block_second_degree_relations_params: [map()],
          transactions_params: [map()],
          withdrawals_params: Withdrawals.params(),
          errors: [Transport.error()]
        }

  defstruct @default_struct_fields ++ @chain_type_struct_fields

  @spec qitmeer_from_responses(list(), map()) :: t()
  def qitmeer_from_responses(responses, id_to_params) when is_list(responses) and is_map(id_to_params) do
    %{errors: errors, blocks: blocks} =
      responses
      |> EthereumJSONRPC.sanitize_responses(id_to_params)
      |> Enum.map(&QitmeerBlock.from_response(&1, id_to_params))
      |> Enum.reduce(%{errors: [], blocks: []}, fn
        {:ok, block}, %{blocks: blocks} = acc ->
          %{acc | blocks: [block | blocks]}

        {:error, error}, %{errors: errors} = acc ->
          %{acc | errors: [error | errors]}
      end)

    elixir_blocks = qitmeer_to_elixir(blocks)

    blocks_params = qitmeer_elixir_to_params(elixir_blocks)

    %__MODULE__{
      errors: errors,
      blocks_params: blocks_params
    }
  end

  @spec qitmeer_elixir_to_params(elixir) :: params()
  def qitmeer_elixir_to_params(elixir) when is_list(elixir) do
    elixir
  end

  @spec qitmeer_to_elixir([Block.t()]) :: elixir
  def qitmeer_to_elixir(blocks) when is_list(blocks) do
    Enum.map(blocks, &QitmeerBlock.to_elixir/1)
  end
end
