defmodule Explorer.Chain.Qitmeer.QitmeerAccount do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:address, :binary, autogenerate: false}
  schema "qitmeer_accounts" do
    field(:balance, :integer)
    field(:tx_count, :integer, default: 0)
    field(:utxo_count, :integer, default: 0)

    timestamps()
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [:address, :balance, :tx_count, :utxo_count])
    |> validate_required([:address, :balance])
  end
end
