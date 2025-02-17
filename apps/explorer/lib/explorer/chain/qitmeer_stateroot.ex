defmodule Explorer.Chain.QitmeerStateRoot do
  @moduledoc """
  """

  use Explorer.Schema

  alias Explorer.Chain.Hash
  alias Explorer.Repo
  @optional_attrs ~w()a

  @required_attrs ~w(valid hash stateroot evm_stateroot evm_head block_order height evm_height)a

  @typedoc """
  How much work is required to find a hash with some number of leading 0s.  It is measured in hashes for PoW
  (Proof-of-Work) chains like Ethereum.  In PoA (Proof-of-Authority) chains, it does not apply as blocks are validated
  in a round-robin fashion, and so the value is always `Decimal.new(0)`.
  """
  @type difficulty :: Decimal.t()

  @typedoc """
  Number of the block in the chain.
  """
  @type block_number :: non_neg_integer()

  @typedoc """
  """
  @type t :: %__MODULE__{
          valid: boolean(),
          hash: String.t(),
          stateroot: String.t(),
          evm_stateroot: String.t(),
          evm_head: String.t(),
          block_order: block_number(),
          height: block_number(),
          evm_height: block_number()
        }

  @primary_key {:block_order, :integer, autogenerate: false}
  schema "qitmeer_stateroot" do
    field(:valid, :boolean)
    field(:stateroot, :string)
    field(:evm_stateroot, :string)
    field(:evm_head, :string)
    field(:hash, :string)
    field(:height, :integer)
    field(:evm_height, :integer)
    timestamps()
  end

  def changeset(%__MODULE__{} = block, attrs) do
    block
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:block_order, name: :qitmeer_stateroot_pkey)
  end

  def number_only_changeset(%__MODULE__{} = block, attrs) do
    block
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required([:number])
    |> unique_constraint(:block_order, name: :qitmeer_stateroot_pkey)
  end

  def insert_stateroot(%{block_order: block_order} = attrs) when not is_nil(block_order) do
    case Repo.get_by(__MODULE__, block_order: block_order) do
      nil ->
        %__MODULE__{}
        |> changeset(attrs)
        |> Repo.insert()

      existing_record ->
        existing_record
        |> changeset(attrs)
        |> Repo.update()
    end
  end

  def check_stateroot(stateroot, block_order) do
    case Repo.get_by(__MODULE__, block_order: block_order) do
      nil ->
        false

      existing_record ->
        existing_record["stateroot"] == stateroot["StateRoot"] &&
          existing_record["evm_stateroot"] == stateroot["EVMStateRoot"] &&
          existing_record["evm_head"] == stateroot["EVMHead"] &&
          existing_record["height"] == stateroot["Height"] &&
          existing_record["evm_height"] == stateroot["EVMHeight"] &&
          existing_record["valid"] == stateroot["Valid"] &&
          existing_record["hash"] == stateroot["Hash"]
    end
  end
end
