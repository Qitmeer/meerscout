defmodule Explorer.Repo.Migrations.CreateQitmeerTransactions do
  use Ecto.Migration

  def change do
    create table(:qitmeer_transactions, primary_key: false) do
      add(:block_hash, references(:qitmeer_blocks, column: :hash, on_delete: :delete_all, type: :bytea), null: true)
      add(:block_order, :integer, null: true)
      # `null` when a pending transaction
      add(:size, :integer, null: true)
      add(:tx_index, :integer, null: true)
      add(:index, :integer, null: true)
      add(:hash, :bytea, null: false)

      add(:lock_time, :integer, null: true)
      add(:to_address, :bytea, null: false)
      add(:amount, :numeric, precision: 100, null: false)
      add(:fee, :numeric, precision: 100, null: true)
      add(:tx_time, :utc_datetime_usec, null: true)
      add(:vin, :bytea, null: false)
      add(:pk_script, :bytea, null: false)
      add(:spent_tx_hash, :bytea, null: true)

      # `null` when a pending transaction
      add(:status, :integer, null: true)

      timestamps(null: false, type: :utc_datetime_usec)

      # `null` when a pending transaction

      # `null` when a pending transaction
      # denormalized from `blocks.number` to improve `Explorer.Chain.recent_collated_transactions/0` performance
    end

    create(unique_index(:qitmeer_transactions, [:hash, :index]))
  end
end
