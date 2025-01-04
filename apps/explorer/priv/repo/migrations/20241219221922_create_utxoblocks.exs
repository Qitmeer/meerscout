defmodule Explorer.Repo.Migrations.CreateQitmeerBlocks do
  use Ecto.Migration

  def change do
    create table(:qitmeer_blocks, primary_key: false) do
      add(:txs_valid, :boolean, null: false)
      add(:difficulty, :numeric, precision: 50)
      add(:confirms, :integer)
      add(:hash, :bytea, null: false, primary_key: true)
      add(:miner_hash, :bytea, null: false)
      add(:coinbase, :numeric, null: false)
      add(:nonce, :bytea, null: false)
      add(:height, :bigint, null: false)
      add(:weight, :bigint, null: false)
      add(:block_order, :bigint, null: false)
      add(:txns, :bigint, null: false)
      add(:pow_name, :bytea, null: false)
      # 0 = pending, 1 = valid, 2 = invalid
      add(:status, :numeric)
      # not a foreign key to allow skipped blocks
      add(:parent_root, :bytea, null: false)

      add(:timestamp, :utc_datetime_usec, null: false)
      add(:insert_catchup, :boolean, null: false)

      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(index(:qitmeer_blocks, [:timestamp]))
    create(index(:qitmeer_blocks, [:hash], unique: true, where: ~s(txs_valid), name: :one_txsvalid_child_per_hash))

    create(
      index(:qitmeer_blocks, [:block_order], unique: true, where: ~s(txs_valid), name: :one_txsvalid_block_at_order)
    )
  end
end
