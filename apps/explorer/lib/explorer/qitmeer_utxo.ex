defmodule Explorer.QitmeerUTXO do
  import Ecto.Query, warn: false
  alias Explorer.Repo
  alias Explorer.Chain.Qitmeer.UTXORecord

  alias Explorer.Chain.Qitmeer.QitmeerAccount

  @doc """
  """
  def list_utxo_records do
    Repo.all(UTXORecord)
  end

  @doc """
  """
  def get_utxo_record!(id), do: Repo.get!(UTXORecord, id)

  @doc """
  """
  def create_utxo_record(attrs \\ %{}) do
    %UTXORecord{}
    |> UTXORecord.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  """
  def update_utxo_record(%UTXORecord{} = record, attrs) do
    record
    |> UTXORecord.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  """
  def delete_utxo_record(%UTXORecord{} = record) do
    Repo.delete(record)
  end

  @doc """
  """
  def change_utxo_record(%UTXORecord{} = record, attrs \\ %{}) do
    UTXORecord.changeset(record, attrs)
  end

  @doc """
  """
  def get_transactions_by_address(address, _params \\ %{}) do
    query =
      from(u in UTXORecord,
        where: u.address == ^address,
        order_by: [desc: u.inserted_at]
      )

    Repo.all(query)
  end

  @doc """
  """
  def get_address_info(address) do
    account = Repo.get_by(QitmeerAccount, address: address)
    utxos = Repo.all(from(u in UTXORecord, where: u.address == ^address))

    if account do
      %{
        address: account.address,
        balance: account.balance,
        utxos: utxos
      }
    else
      %{
        address: address,
        balance: 0,
        utxos: []
      }
    end
  end
end
