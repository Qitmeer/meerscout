defmodule Explorer.Chain.QitmeerAddress do
  @moduledoc """
  A stored representation of a web3 address.
  """

  require Bitwise

  use Explorer.Schema

  alias Ecto.Changeset
  alias Explorer.Repo

  @optional_attrs ~w(spent)a
  @required_attrs ~w(address available unavailable)a
  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
   * `fetched_coin_balance` - The last fetched balance from Nethermind
   * `fetched_coin_balance_block_number` - the `t:Explorer.Chain.Block.t/0` `t:Explorer.Chain.Block.block_number/0` for
     which `fetched_coin_balance` was fetched
   * `hash` - the hash of the address's public key
   * `contract_code` - the binary code of the contract when an Address is a contract.  The human-readable
     Solidity source code is in `smart_contract` `t:Explorer.Chain.SmartContract.t/0` `contract_source_code` *if* the
    contract has been verified
   * `names` - names known for the address
   * `inserted_at` - when this address was inserted
   * `updated_at` when this address was last updated
   `fetched_coin_balance` and `fetched_coin_balance_block_number` may be updated when a new coin_balance row is fetched.
    They may also be updated when the balance is fetched via the on demand fetcher.
  """
  @type t :: %__MODULE__{
          address: String.t(),
          available: Decimal.t(),
          unavailable: Decimal.t(),
          spent: Decimal.t()
        }

  @primary_key {:address, :string, autogenerate: false}
  schema "qitmeer_address_balance" do
    field(:available, :decimal)
    field(:unavailable, :decimal)
    field(:spent, :decimal)
    timestamps()
  end

  @balance_changeset_required_attrs @required_attrs ++ ~w(address available unavailable)a

  def balance_changeset(%__MODULE__{} = address, attrs) do
    address
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@balance_changeset_required_attrs)
    |> changeset()
  end

  def changeset(%__MODULE__{} = address, attrs) do
    address
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:address)
  end

  defp changeset(%Changeset{data: %__MODULE__{}} = changeset) do
    changeset
    |> validate_required(@required_attrs)
    |> unique_constraint(:address)
  end

  def qitmeer_address_update(address, amount) do
    addr = Repo.one(from(u in __MODULE__, where: u.address == ^address))

    case addr do
      nil ->
        attrs = %{
          address: address,
          available: amount,
          unavailable: 0,
          spent: 0
        }

        %__MODULE__{}
        |> changeset(attrs)
        |> Repo.insert!()

      addr ->
        old_amount = Decimal.new(addr.available)
        new_amount = Decimal.new(amount)
        changeset = Changeset.change(addr, available: Decimal.add(old_amount, new_amount))

        case Repo.update(changeset) do
          {:ok, updated_tx} ->
            {:ok, updated_tx}

          {:error, changeset} ->
            {:error, changeset.errors}
        end
    end
  end
end
