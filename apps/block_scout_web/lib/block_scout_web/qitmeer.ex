defmodule BlockScoutWeb.QitmeerChain do
  @moduledoc """
  Converts the `param` to the corresponding resource that uses that format of param.
  """

  alias BlockScoutWeb.Chain, as: BlockScoutWebChain

  alias Explorer.Chain.{
    QitmeerBlock,
    QitmeerTransaction
  }

  defp paging_params(%QitmeerBlock{block_order: block_order}) do
    %{"block_number" => block_order}
  end

  defp paging_params(%QitmeerTransaction{block_order: nil, inserted_at: inserted_at, hash: hash}) do
    %{"inserted_at" => DateTime.to_iso8601(inserted_at), "hash" => hash}
  end

  defp paging_params(%QitmeerTransaction{block_order: block_number, tx_index: index}) do
    %{"block_order" => block_number, "tx_index" => index}
  end

  @spec next_page_params(any, list(), map(), (any -> map())) :: nil | map
  def next_page_params(next_page, list, params, paging_function \\ &paging_params/1)

  def next_page_params([], _list, _params, _), do: nil

  def next_page_params(_, list, params, paging_function) do
    paging_params = paging_function.(List.last(list))

    next_page_params = Map.merge(params, paging_params)
    current_items_count_string = Map.get(next_page_params, "items_count")

    items_count =
      if is_binary(current_items_count_string) do
        {current_items_count, _} = Integer.parse(current_items_count_string)
        current_items_count + Enum.count(list)
      else
        Enum.count(list)
      end

    Map.put(next_page_params, "items_count", items_count)
  end

  def parse_qitmeer_block_hash_or_number_param(hash) when is_binary(hash) do
    case BlockScoutWebChain.param_to_block_number(hash) do
      {:ok, number} ->
        {:ok, :number, number}

      {:error, :invalid} ->
        {:ok, :hash, hash}
    end
  end
end
