defmodule Explorer.QitmeerChain do
  @moduledoc """
  The chain context.
  """

  import Ecto.Query,
    only: [
      from: 2,
      limit: 2,
      order_by: 2,
      order_by: 3,
      where: 2,
      where: 3
    ]

  import Explorer.Chain, only: [select_repo: 1, pending_transactions_query: 1]

  require Logger

  alias Explorer.Chain.{
    Block,
    QitmeerAddress,
    QitmeerBlock,
    QitmeerTransaction,
    Transaction
  }

  alias Explorer.PagingOptions

  @default_page_size 50
  @default_paging_options %PagingOptions{page_size: @default_page_size}

  @typedoc """
  The name of an association on the `t:Ecto.Schema.t/0`
  """
  @type association :: atom()

  @typedoc """
  The max `t:Explorer.Chain.Block.block_number/0` for `consensus` `true` `t:Explorer.Chain.Block.t/0`s.
  """
  @type block_height :: Block.block_number()

  @typedoc """
  Event type where data is broadcasted whenever data is inserted from chain indexing.
  """
  @type chain_event ::
          :addresses
          | :address_coin_balances
          | :blocks
          | :block_rewards
          | :exchange_rate
          | :internal_transactions
          | :logs
          | :transactions
          | :token_transfers

  @type direction :: :from | :to

  @typedoc """
   * `:optional` - the association is optional and only needs to be loaded if available
   * `:required` - the association is required and MUST be loaded.  If it is not available, then the parent struct
     SHOULD NOT be returned.
  """
  @type necessity :: :optional | :required

  @typedoc """
  The `t:necessity/0` of each association that should be loaded
  """
  @type necessity_by_association :: %{association => necessity}

  @type necessity_by_association_option :: {:necessity_by_association, necessity_by_association}
  @type paging_options :: {:paging_options, PagingOptions.t()}
  @type api? :: {:api?, true | false}

  def address_to_qitmeer_transactions(address_hash, options, _old_ui? \\ true) do
    QitmeerTransaction
    |> where([transaction], transaction.to_address == ^address_hash)
    |> select_repo(options).all()
  end

  def where_qitmeer_block_number_in_period(base_query, from_block, to_block)
      when is_nil(from_block) and is_nil(to_block) do
    base_query
  end

  def where_qitmeer_block_number_in_period(base_query, from_block, to_block)
      when is_nil(from_block) and not is_nil(to_block) do
    from(q in base_query,
      where: q.block_order <= ^to_block
    )
  end

  def where_qitmeer_block_number_in_period(base_query, from_block, to_block)
      when not is_nil(from_block) and is_nil(to_block) do
    from(q in base_query,
      where: q.block_order > ^from_block
    )
  end

  def where_qitmeer_block_number_in_period(base_query, from_block, to_block)
      when is_nil(from_block) and is_nil(to_block) do
    base_query
  end

  def where_qitmeer_block_number_in_period(base_query, from_block, to_block) do
    from(q in base_query,
      where: q.block_order > ^from_block and q.block_order <= ^to_block
    )
  end

  def block_to_qitmeer_transactions(block_hash, options \\ [], _old_ui? \\ true) when is_list(options) do
    options
    |> Keyword.get(:paging_options, @default_paging_options)
    |> fetch_transactions_in_ascending_order_by_qitmeer_index()
    |> where([transaction], transaction.block_hash == ^block_hash)
    |> select_repo(options).all()
  end

  def hash_to_qitmeer_block(hash, options \\ []) when is_list(options) do
    QitmeerBlock
    |> where(hash: ^hash)
    |> select_repo(options).one()
    |> case do
      nil ->
        {:error, :not_found}

      block ->
        {:ok, block}
    end
  end

  def hash_to_qitmeer_transaction(hash, options \\ [])
      when is_list(options) do
    QitmeerTransaction
    |> where(hash: ^hash)
    |> select_repo(options).one()
    |> case do
      nil ->
        {:error, :not_found}

      transaction ->
        {:ok, transaction}
    end
  end

  def qitmeer_address(addr, options \\ []) do
    QitmeerAddress
    |> where(address: ^addr)
    |> select_repo(options).one()
  end

  @spec list_qitmeer_blocks([paging_options | necessity_by_association_option | api?]) :: [QitmeerBlock.t()]
  def list_qitmeer_blocks(options \\ []) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options) || @default_paging_options
    fetch_qitmeer_blocks(paging_options, necessity_by_association, options)
  end

  defp fetch_qitmeer_blocks(paging_options, _necessity_by_association, options) do
    QitmeerBlock
    |> QitmeerBlock.block_filter()
    |> page_qitmeer_blocks(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by(desc: :block_order)
    |> select_repo(options).all()
  end

  def qitmeer_block_order(options \\ []) do
    query = from(block in QitmeerBlock, select: coalesce(max(block.block_order), 0), where: block.txs_valid == true)

    select_repo(options).one!(query)
  end

  def number_to_qitmeer_block(number, options \\ []) when is_list(options) do
    QitmeerBlock
    |> where(txs_valid: true, block_order: ^number)
    |> select_repo(options).one()
    |> case do
      nil -> {:error, :not_found}
      block -> {:ok, block}
    end
  end

  def recent_collated_qitmeer_transactions(_old_ui?, options \\ [])
      when is_list(options) do
    # necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    fetch_recent_collated_qitmeer_transactions(
      paging_options,
      options
    )
  end

  def fetch_recent_collated_qitmeer_transactions(
        paging_options,
        options
      ) do
    paging_options
    |> fetch_qitmeer_transactions()
    |> where([transaction], not is_nil(transaction.block_order) and not is_nil(transaction.tx_index))
    |> select_repo(options).all()
  end

  def recent_pending_qitmeer_transactions(options \\ [], _old_ui? \\ true)
      when is_list(options) do
    # necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    QitmeerTransaction
    |> page_pending_qitmeer_transaction(paging_options)
    |> limit(^paging_options.page_size)
    |> pending_transactions_query()
    |> order_by([transaction], desc: transaction.inserted_at, asc: transaction.hash)
    |> select_repo(options).all()
  end

  defp fetch_qitmeer_transactions(paging_options, from_block \\ nil, to_block \\ nil, with_pending? \\ false) do
    QitmeerTransaction
    |> order_for_qitmeer_transactions(with_pending?)
    |> where_qitmeer_block_number_in_period(from_block, to_block)
    |> Transaction.handle_paging_options(paging_options)
  end

  defp order_for_qitmeer_transactions(query, pending) when not pending do
    query
    |> order_by([transaction], desc: transaction.block_order, desc: transaction.tx_index)
  end

  defp fetch_transactions_in_ascending_order_by_qitmeer_index(paging_options) do
    QitmeerTransaction
    |> order_by([transaction], asc: transaction.tx_index)
    |> handle_block_paging_options(paging_options)
  end

  defp page_block_transactions(query, %PagingOptions{key: nil}), do: query

  defp page_block_transactions(query, %PagingOptions{key: {_block_number, index}, is_index_in_asc_order: true}) do
    where(query, [transaction], transaction.tx_index > ^index)
  end

  defp page_block_transactions(query, %PagingOptions{key: {_block_number, index}}) do
    where(query, [transaction], transaction.tx_index < ^index)
  end

  defp handle_block_paging_options(query, nil), do: query

  defp handle_block_paging_options(query, %PagingOptions{key: nil, page_size: nil}), do: query

  defp handle_block_paging_options(query, paging_options) do
    case paging_options do
      %PagingOptions{key: {_block_number, 0}, is_index_in_asc_order: false} ->
        []

      _ ->
        query
        |> page_block_transactions(paging_options)
        |> limit(^paging_options.page_size)
    end
  end

  defp page_qitmeer_blocks(query, %PagingOptions{key: nil}), do: query

  defp page_qitmeer_blocks(query, %PagingOptions{key: {block_number}}) do
    where(query, [qitmeer_block], qitmeer_block.block_order < ^block_number)
  end

  defp page_pending_qitmeer_transaction(query, %PagingOptions{key: nil}), do: query

  defp page_pending_qitmeer_transaction(query, %PagingOptions{key: {inserted_at, hash}}) do
    where(
      query,
      [transaction],
      (is_nil(transaction.block_order) and
         (transaction.inserted_at < ^inserted_at or
            (transaction.inserted_at == ^inserted_at and transaction.hash > ^hash))) or
        not is_nil(transaction.block_order)
    )
  end

  def recent_qitmeer_transactions(options, [:pending | _]) do
    recent_pending_qitmeer_transactions(options, false)
  end

  def recent_qitmeer_transactions(options, _) do
    recent_collated_qitmeer_transactions(false, options)
  end
end
