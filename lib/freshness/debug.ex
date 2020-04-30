defmodule Freshness.Debug do
  @moduledoc """
  A module with debugging helpers for the library. Calling functions from this module
  can be expensive, so you should avoid making these calls in production
  """
  alias Freshness.Config
  alias Freshness.Pool

  @doc """
  Get the total connection across all servers for the given pool
  """
  @spec connection_count(Config.pool_name()) :: non_neg_integer()
  def connection_count(pool_name) do
    [{pid, _data}] = Registry.lookup(Config.registry_name(), pool_name)

    pid
    |> Supervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> :sys.get_state(pid) end)
    |> Enum.map(fn %{pool: pool} -> Pool.length(pool) end)
    |> Enum.sum()
  end
end
