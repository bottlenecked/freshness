defmodule Freshness do
  @external_resource "README.md"
  @moduledoc File.read!(@external_resource)
  alias Freshness.{Config, Server, Response}

  @type request_options() :: [request_option()]
  @type request_option() :: {:timeout, non_neg_integer()}

  @doc """
  Make a GET request using the given pool
  """
  @spec get(
          Config.pool_name(),
          path :: String.t(),
          Mint.Types.headers(),
          request_options()
        ) ::
          {:ok, Response.t()}
          | {:error, term()}
  def get(server, path, headers \\ [], options \\ []),
    do: request(server, "GET", path, headers, "", options)

  @doc """
  Make a request to the configured Freshness pool
  """
  @spec request(
          Config.pool_name(),
          method :: String.t(),
          path :: String.t(),
          Mint.Types.headers(),
          body :: iodata() | nil | :stream,
          request_options()
        ) ::
          {:ok, Response.t()}
          | {:error, term()}
  def request(pool_name, method, path, headers \\ [], body \\ "", options \\ []) do
    # grab the counter
    [{_pid, {counter_ref, count}}] = Registry.lookup(Config.registry_name(), pool_name)
    # get and update current index
    index =
      counter_ref
      |> :atomics.add_get(1, 1)
      |> rem(count)

    server = Server.via_tuple(pool_name, index)
    Server.request(server, method, path, headers, body, options)
  end
end
