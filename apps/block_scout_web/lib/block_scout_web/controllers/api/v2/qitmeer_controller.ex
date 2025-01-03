defmodule BlockScoutWeb.API.V2.QitmeerController do
  use BlockScoutWeb, :controller
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  import BlockScoutWeb.Chain,
    only: [
      paging_options: 1,
      put_key_value_to_paging_options: 3,
      split_list_by_page: 1
    ]

  import BlockScoutWeb.QitmeerChain,
    only: [
      parse_qitmeer_block_hash_or_number_param: 1,
      next_page_params: 3
    ]

  import BlockScoutWeb.PagingHelper,
    only: [
      delete_parameters_from_next_page_params: 1,
      select_block_type: 1,
      method_filter_options: 1,
      type_filter_options: 1,
      paging_options: 2,
      filter_options: 2
    ]

  alias BlockScoutWeb.API.V2.QitmeerView

  alias Explorer.{Chain, QitmeerChain}

  @api_true [api?: true]

  @block_params [
    necessity_by_association: %{
      [miner: [:names, :smart_contract, proxy_implementations_association()]] => :optional,
      :transactions => :optional
    },
    api?: true
  ]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def qitmeer_block(conn, %{"block_hash_or_number" => block_hash_or_number}) do
    with {:ok, type, value} <- parse_qitmeer_block_hash_or_number_param(block_hash_or_number),
         {:ok, block} <- fetch_qitmeer_block(type, value, @block_params) do
      conn
      |> put_status(200)
      |> put_view(QitmeerView)
      |> render(:qitmeer_block, %{block: block})
    end
  end

  defp fetch_qitmeer_block(:hash, hash, params) do
    QitmeerChain.hash_to_qitmeer_block(hash, params)
  end

  defp fetch_qitmeer_block(:number, number, params) do
    case QitmeerChain.number_to_qitmeer_block(number, params) do
      {:ok, _block} = ok_response ->
        ok_response

      _ ->
        {:lost_consensus, Chain.nonconsensus_block_by_number(number, @api_true)}
    end
  end

  def qitmeer_blocks(conn, params) do
    full_options = select_block_type(params)

    blocks_plus_one =
      full_options
      |> Keyword.merge(paging_options(params))
      |> Keyword.merge(@api_true)
      |> QitmeerChain.list_qitmeer_blocks()

    {blocks, next_page} = split_list_by_page(blocks_plus_one)

    next_page_params = next_page |> next_page_params(blocks, delete_parameters_from_next_page_params(params))

    conn
    |> put_status(200)
    |> put_view(QitmeerView)
    |> render(:qitmeer_blocks, %{blocks: blocks, next_page_params: next_page_params})
  end

  def qitmeer_block_transactions(conn, %{"block_hash_or_number" => block_hash_or_number} = params) do
    with {:ok, type, value} <- parse_qitmeer_block_hash_or_number_param(block_hash_or_number),
         {:ok, block} <- fetch_qitmeer_block(type, value, @api_true) do
      full_options =
        params
        |> paging_options()
        |> put_key_value_to_paging_options(:is_index_in_asc_order, true)
        |> Keyword.merge(@api_true)

      transactions_plus_one = QitmeerChain.block_to_qitmeer_transactions(block.hash, full_options, false)

      {transactions, next_page} = split_list_by_page(transactions_plus_one)

      next_page_params =
        next_page
        |> next_page_params(transactions, delete_parameters_from_next_page_params(params))

      conn
      |> put_status(200)
      |> put_view(QitmeerView)
      |> render(:qitmeer_transactions, %{transactions: transactions, next_page_params: next_page_params})
    end
  end

  def qitmeer_address(conn, %{"address_hash_param" => address_hash_string}) do
    addr_info = QitmeerChain.qitmeer_address(address_hash_string, [])

    conn
    |> put_status(200)
    |> put_view(QitmeerView)
    |> render(:qitmeer_address, %{addr_info: addr_info})
  end

  def qitmeer_address_transactions(conn, %{"address_hash_param" => address_hash_string} = params) do
    results_plus_one = QitmeerChain.address_to_qitmeer_transactions(address_hash_string, [], false)
    {transactions, next_page} = split_list_by_page(results_plus_one)

    next_page_params = next_page |> next_page_params(transactions, delete_parameters_from_next_page_params(params))

    conn
    |> put_status(200)
    |> put_view(QitmeerView)
    |> render(:qitmeer_transactions, %{transactions: transactions, next_page_params: next_page_params})
  end

  def qitmeer_transaction(conn, %{"transaction_hash_param" => transaction_hash_string}) do
    with {:ok, transaction} <-
           QitmeerChain.hash_to_qitmeer_transaction(
             transaction_hash_string,
             necessity_by_association: %{},
             api?: true
           ) do
      conn
      |> put_status(200)
      |> put_view(QitmeerView)
      |> render(:qitmeer_transaction, %{transaction: transaction})
    end
  end

  def qitmeer_transactions(conn, params) do
    filter_options = filter_options(params, :validated)

    full_options =
      []
      |> Keyword.merge(paging_options(params, filter_options))
      |> Keyword.merge(method_filter_options(params))
      |> Keyword.merge(type_filter_options(params))
      |> Keyword.merge(@api_true)

    transactions_plus_one = QitmeerChain.recent_qitmeer_transactions(full_options, filter_options)

    {transactions, next_page} = split_list_by_page(transactions_plus_one)

    next_page_params = next_page |> next_page_params(transactions, delete_parameters_from_next_page_params(params))

    conn
    |> put_status(200)
    |> render(:qitmeer_transactions, %{transactions: transactions, next_page_params: next_page_params})
  end
end
