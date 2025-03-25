defmodule BlockScoutWeb.Routers.QitmeerRouter do
  @moduledoc """
  Router for qitmeer-related requests
  """
  use BlockScoutWeb, :router

  alias BlockScoutWeb.API.V2.QitmeerController
  alias BlockScoutWeb.API.V2.QitmeerV2Controller

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
    get("/:address", QitmeerV2Controller, :utxo_address_info)
    get("/:address/transactions", QitmeerV2Controller, :utxo_transactions)
  end

  scope "/network" do
    get("/status", QitmeerV2Controller, :network_status)
    get("/hashrate", QitmeerV2Controller, :hashrate_stats)
    get("/nodes", QitmeerV2Controller, :node_status)
  end

  scope "/accounts" do
    get("/", QitmeerV2Controller, :accounts_list)
  end
end
