defmodule Explorer.Repo.Migrations.CreateQitmeerStateRoot do
  use Ecto.Migration

  def change do
    create table(:qitmeer_stateroot, primary_key: false) do
      add(:valid, :boolean, null: false)
      add(:hash, :string, null: false)
      add(:evm_stateroot, :string, null: false)
      add(:evm_head, :string, null: false)
      add(:stateroot, :string, null: false)
      add(:block_order, :bigint, null: false)
      add(:height, :bigint, null: false)
      add(:evm_height, :bigint, null: false)
      timestamps(null: false, type: :utc_datetime_usec)
    end

    create(unique_index(:qitmeer_stateroot, [:block_order]))
  end
end
