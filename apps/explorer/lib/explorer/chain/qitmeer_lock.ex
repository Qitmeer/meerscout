defmodule Explorer.Chain.QitmeerLock do
  @moduledoc """
  Qitmeer Lock module
  """
  def acquire_lock(lock_name) do
    case :global.register_name(lock_name, self()) do
      :yes ->
        :ok

      :no ->
        {:error, "Lock already acquired"}
    end
  end

  def release_lock(lock_name) do
    :global.unregister_name(lock_name)
  end
end
