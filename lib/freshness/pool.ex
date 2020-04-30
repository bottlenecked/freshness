defmodule Freshness.Pool do
  @moduledoc ~S"""
  A simple pool backed by a :queue to store connections

  ## Usage

  To create a pool call the new/4 function

    pool = Freshness.Pool.new(:http, "google.com", 80)

  To checkout a connection from the pool use the checkout/1 function.
  Note: if there are no connections in the pool a new one will be created and returned

    {:ok, pool, connection} = Freshness.Pool.checkout(pool)

  You may also get an error if there are no connections in the pool and a new connection
  cannot be opened

    {:error, error} = Freshness.Pool.checkout(pool)

  To return a connection back to the pool use the checkin/2 function

    pool = Freshness.Pool.checkin(pool, connection)

  """

  @type t() :: %__MODULE__{}

  defstruct [
    :scheme,
    :host,
    :port,
    :opts,
    connections: :queue.new()
  ]

  @spec new(Mint.Types.scheme(), String.t(), :inet.port_number(), keyword()) :: t()
  def new(scheme, host, port, opts \\ []) do
    %__MODULE__{scheme: scheme, host: host, port: port, opts: opts}
  end

  @spec checkout(t()) :: {:ok, t(), Mint.HTTP.t()} | {:error, Mint.Types.error()}
  def checkout(%__MODULE__{connections: connections} = pool) do
    case :queue.out(connections) do
      {{:value, conn}, rest} ->
        {:ok, %{pool | connections: rest}, conn}

      {:empty, _queue} ->
        case Mint.HTTP.connect(pool.scheme, pool.host, pool.port, pool.opts) do
          {:ok, conn} -> {:ok, pool, conn}
          other -> other
        end
    end
  end

  @spec checkin(t(), Mint.HTTP.t()) :: t()
  def checkin(pool, connection)

  def checkin(%__MODULE__{connections: connections} = pool, %http{state: :open} = conn)
      when http in [Mint.HTTP1, Mint.HTTP2] do
    %{pool | connections: :queue.in(conn, connections)}
  end

  def checkin(%__MODULE__{} = pool, _), do: pool

  @spec empty?(t()) :: boolean
  def empty?(%__MODULE__{connections: connections}), do: :queue.is_empty(connections)

  @spec length(t()) :: non_neg_integer
  def length(%__MODULE__{connections: connections}), do: :queue.len(connections)
end
