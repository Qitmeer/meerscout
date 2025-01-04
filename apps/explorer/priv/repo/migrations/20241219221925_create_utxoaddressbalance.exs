defmodule Explorer.Repo.Migrations.CreateQitmeerAddressBalance do
  use Ecto.Migration

  def change do
    create table(:qitmeer_address_balance, primary_key: false) do
      add(:address, :string, null: true)
      add(:available, :numeric, precision: 100, null: false)
      add(:unavailable, :numeric, precision: 100, null: false)
      add(:spent, :numeric, precision: 100, null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:qitmeer_address_balance, [:address]))
  end
end
