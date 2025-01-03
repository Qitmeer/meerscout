defmodule Explorer.Chain.QitmeerTransaction do
  @moduledoc "Models a Web3 transaction."

  use Explorer.Schema

  require Logger
  alias Explorer.Repo
  import Ecto.Query, only: [from: 2, where: 3]
  import Explorer.Chain.QitmeerAddress, only: [qitmeer_address_update: 2]
  alias Ecto.Changeset

  alias Explorer.Chain.Transaction

  @optional_attrs ~w(block_hash block_order tx_index lock_time spent_tx_hash tx_time status fee)a

  @required_attrs ~w(hash index size to_address amount vin pk_script)a

  @typedoc """
  The index of the transaction in its block.
  """
  @type transaction_index :: non_neg_integer()

  @typedoc """
  `t:standard_v/0` + `27`
  | `v`  | X      | Y    |
  |------|--------|------|
  | `27` | lower  | even |
  | `28` | lower  | odd  |
  | `29` | higher | even |
  | `30` | higher | odd  |
  **Note: that `29` and `30` are exceedingly rarely, and will in practice only ever be seen in specifically generated
  examples.**
  """
  @type t :: %__MODULE__{
          block_hash: String.t() | nil,
          block_order: non_neg_integer() | nil,
          size: non_neg_integer(),
          tx_index: non_neg_integer(),
          index: non_neg_integer(),
          hash: String.t(),
          lock_time: non_neg_integer() | nil,
          to_address: String.t(),
          amount: Decimal.t(),
          fee: Decimal.t(),
          spent_tx_hash: String.t() | nil,
          tx_time: DateTime.t(),
          vin: String.t(),
          pk_script: String.t(),
          status: non_neg_integer()
        }

  @primary_key false
  schema "qitmeer_transactions" do
    field(:block_hash, :string)
    field(:block_order, :integer)
    field(:size, :integer)
    field(:tx_index, :integer)
    field(:index, :integer)
    field(:hash, :string)
    field(:lock_time, :integer)
    field(:to_address, :string)
    field(:amount, :decimal)
    field(:fee, :decimal)
    field(:spent_tx_hash, :string)
    field(:tx_time, :utc_datetime_usec)
    field(:vin, :string)
    field(:pk_script, :string)
    field(:status, :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = transaction, attrs \\ %{}) do
    attrs_to_cast = @required_attrs ++ @optional_attrs

    transaction
    |> cast(attrs, attrs_to_cast)
    |> validate_required(@required_attrs)
  end

  def not_pending_transactions(query) do
    where(query, [t], not is_nil(t.block_order))
  end

  def insert_tx(%{hash: _hash} = attrs) do
    qitmeer_address_update(attrs.to_address, attrs.amount)

    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert!()
  end

  def insert_tx(%{:error => err}) do
    {:error, err}
  end

  @doc """
  Builds an `Ecto.Query` to fetch transactions with the specified block_order
  """
  def transactions_with_block_order(block_order) do
    from(
      t in Transaction,
      where: t.block_order == ^block_order
    )
  end

  def qitmeer_tx_update_status(hash, index, spent_tx_hash) do
    tx = Repo.one(from(u in __MODULE__, where: u.hash == ^hash and u.index == ^index))

    case tx do
      nil ->
        {:error, "tx not found"}

      tx ->
        changeset = Changeset.change(tx, spent_tx_hash: spent_tx_hash, status: 1)

        case Repo.update(changeset) do
          {:ok, updated_tx} ->
            qitmeer_address_update(tx.to_address, -tx.amount)
            {:ok, updated_tx}

          {:error, changeset} ->
            {:error, changeset.errors}
        end
    end
  end
end
