defmodule Freshness do
  @external_resource "README.md"
  @moduledoc File.read!(@external_resource)
  alias Freshness.{Config, Server, Response}

  @doc """
  Make a GET request using the given pool
  """
  @spec get(
          Config.pool_name(),
          path :: String.t(),
          Mint.Types.headers()
        ) ::
          {:ok, Response.t()}
          | {:error, term()}
  def get(server, path, headers \\ []), do: request(server, "GET", path, headers, "")

  @doc """
  Make a request to the configured Freshness pool
  """
  @spec request(
          Config.pool_name(),
          method :: String.t(),
          path :: String.t(),
          Mint.Types.headers(),
          body :: iodata() | nil | :stream
        ) ::
          {:ok, Response.t()}
          | {:error, term()}
  def request(pool_name, method, path, headers \\ [], body \\ "") do
    # grab the counter
    [{_pid, {counter_ref, count}}] = Registry.lookup(Config.registry_name(), pool_name)
    # get and update current index
    index =
      counter_ref
      |> :atomics.add_get(1, 1)
      |> rem(count)

    server = Server.via_tuple(pool_name, index)
    Server.request(server, method, path, headers, body)
  end
end
