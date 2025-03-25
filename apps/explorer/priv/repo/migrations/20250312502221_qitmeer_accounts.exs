defmodule Explorer.Repo.Migrations.CreateQitmeerAccounts do
  use Ecto.Migration

  def change do
    create table(:qitmeer_accounts, primary_key: false) do
      add(:address, :bytea, null: false, primary_key: true)
      add(:balance, :numeric, precision: 100, null: false, default: 0)
      add(:tx_count, :bigint, null: false, default: 0)
      add(:utxo_count, :bigint, null: false, default: 0)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:qitmeer_accounts, [:address]))
  end
end
