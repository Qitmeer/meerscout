defmodule Explorer.Repo.Migrations.CreateQitmeerUtxoRecords do
  use Ecto.Migration

  def change do
    create table(:qitmeer_utxo_records, primary_key: false) do
      add(:tx_hash, :bytea, null: false)
      add(:index, :integer, null: false)
      add(:address, :bytea, null: false)
      add(:amount, :numeric, precision: 100, null: false)
      add(:block_height, :bigint, null: false)
      add(:spent, :boolean, null: false, default: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:qitmeer_utxo_records, [:address]))
    create(index(:qitmeer_utxo_records, [:tx_hash]))
  end
end
