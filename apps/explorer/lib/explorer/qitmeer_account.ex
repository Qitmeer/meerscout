defmodule Explorer.QitmeerAccounts do
  import Ecto.Query, warn: false
  alias Explorer.Repo
  alias Explorer.Chain.Qitmeer.QitmeerAccount

  @doc """
  list
  """
  def list_accounts do
    Repo.all(QitmeerAccount)
  end

  @doc """
  """
  def get_account!(id), do: Repo.get!(QitmeerAccount, id)

  @doc """
  """
  def create_account(attrs \\ %{}) do
    %QitmeerAccount{}
    |> QitmeerAccount.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  """
  def update_account(%QitmeerAccount{} = account, attrs) do
    account
    |> QitmeerAccount.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  """
  def delete_account(%QitmeerAccount{} = account) do
    Repo.delete(account)
  end

  @doc """
  """
  def change_account(%QitmeerAccount{} = account, attrs \\ %{}) do
    QitmeerAccount.changeset(account, attrs)
  end

  @doc """
  """
  def list_sorted_accounts(_params \\ %{}) do
    query =
      from(a in QitmeerAccount,
        order_by: [desc: a.balance],
        select: %{address: a.address, balance: a.balance, tx_count: a.tx_count, utxo_count: a.utxo_count}
      )

    Repo.all(query)
  end
end
