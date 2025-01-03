defmodule BlockScoutWeb.Routers.QitmeerRouter do
  @moduledoc """
  Router for qitmeer-related requests
  """
  use BlockScoutWeb, :router

  alias BlockScoutWeb.API.V2.QitmeerController

  # /api/v2/qitmeer/

  scope "/blocks" do
    get("/", QitmeerController, :qitmeer_blocks)
    get("/:block_hash_or_number", QitmeerController, :qitmeer_block)
    get("/:block_hash_or_number/transactions", QitmeerController, :qitmeer_block_transactions)
  end

  scope "/transactions" do
    get("/", QitmeerController, :qitmeer_transactions)
    get("/:transaction_hash_param", QitmeerController, :qitmeer_transaction)
  end

  scope "/addresses" do
    get("/:address_hash_param", QitmeerController, :qitmeer_address)
    get("/:address_hash_param/transactions", QitmeerController, :qitmeer_address_transactions)
  end
end
