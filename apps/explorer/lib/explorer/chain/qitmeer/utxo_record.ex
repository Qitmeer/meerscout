defmodule Explorer.Chain.Qitmeer.UTXORecord do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "qitmeer_utxo_records" do
    field(:address, :string)
    field(:amount, :integer)
    field(:spent, :boolean, default: false)
    field(:tx_hash, :string)

    timestamps()
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [:address, :amount, :spent, :tx_hash])
    |> validate_required([:address, :amount, :tx_hash])
  end
end
