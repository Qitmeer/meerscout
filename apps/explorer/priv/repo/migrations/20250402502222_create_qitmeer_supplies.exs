defmodule Explorer.Repo.Migrations.CreateQitmeerSupplies do
  use Ecto.Migration

  def change do
    create table(:qitmeer_supplies) do
      add(:total_supply, :decimal, null: false)
      add(:block_height, :integer, null: false)
      add(:block_hash, :string, null: false)
      add(:timestamp, :utc_datetime_usec, null: false)

      timestamps()
    end

    create(index(:qitmeer_supplies, [:block_height]))
    create(unique_index(:qitmeer_supplies, [:block_hash]))
  end
end
