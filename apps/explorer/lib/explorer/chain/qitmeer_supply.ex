defmodule Explorer.Chain.QitmeerSupply do
  use Explorer.Schema

  schema "qitmeer_supplies" do
    field(:total_supply, :decimal)
    field(:block_height, :integer)
    field(:block_hash, :string)
    field(:timestamp, :utc_datetime_usec)

    timestamps()
  end

  def changeset(%__MODULE__{} = supply, attrs) do
    supply
    |> cast(attrs, [:total_supply, :block_height, :block_hash, :timestamp])
    |> validate_required([:total_supply, :block_height, :block_hash, :timestamp])
  end
end
