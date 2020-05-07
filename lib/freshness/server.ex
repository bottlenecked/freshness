defmodule Freshness.Server do
  @moduledoc ~S"""
  A genserver module holding open connections to the same (host, port, protocol) socket.
  It is meant as a light-weight pooling mechanism that exposes raw mint replies
  """
  use GenServer

  alias Freshness.{Config, Pool, PendingRequest, Response}
  alias Freshness.Config.MintConfig

  @type t() :: %__MODULE__{}

  defstruct [
    :pool,
    pending: Map.new()
  ]

  @spec start_link(Freshness.Config.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(%Config{} = config) do
    GenServer.start_link(__MODULE__, config.mint, name: via_tuple(config.name, config.index))
  end

  @impl true
  @spec init(MintConfig.t()) :: {:ok, t()}
  def init(%MintConfig{} = config) do
    pool = Pool.new(config.scheme, config.host, config.port, config.options)

    {:ok, %__MODULE__{pool: pool}}
  end

  @spec request(
          GenServer.server(),
          method :: String.t(),
          path :: String.t(),
          Mint.Types.headers(),
          body :: iodata() | nil | :stream,
          options :: Freshness.request_options()
        ) ::
          {:ok, Response.t()}
          | {:error, term()}
  def request(server, method, path, headers \\ [], body \\ "", options \\ []) do
    timeout = options[:timeout]
    timeout = (timeout > 0 && timeout) || 5000
    expiration = Utils.expiration(timeout)
    request_params = {method, path, headers, body, expiration}

    try do
      GenServer.call(server, {:request, request_params}, timeout)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
    end
  end

  @impl true
  def handle_call({:request, request_params}, from, %{pool: pool} = state) do
    {method, path, headers, body, expiration} = request_params

    with {:expired?, false} <- {:expired?, Utils.expired?(expiration)},
         {:checkout, {:ok, new_pool, conn}} <- {:checkout, Pool.checkout(pool)},
         request_result = Mint.HTTP.request(conn, method, path, headers, body),
         {:request, {:ok, conn, _request_ref}, _new_pool} <- {:request, request_result, new_pool} do
      request = %PendingRequest{connection: conn, from: from, expiration: expiration}
      pending = Map.put(state.pending, conn.socket, request)
      {:noreply, %{state | pending: pending, pool: new_pool}}
    else
      {:expired?, true} ->
        {:reply, {:error, :timeout}, state}

      {:checkout, error} ->
        {:reply, error, state}

      {:request, {:error, _http, reason}, new_pool} ->
        state = %{state | pool: new_pool}
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info({_tag, socket, _data} = msg, state) when is_port(socket) do
    handle_socket_message(socket, msg, state)
  end

  @impl true
  def handle_info({_tag, socket} = msg, state) when is_port(socket) do
    handle_socket_message(socket, msg, state)
  end

  defp handle_socket_message(socket, msg, %__MODULE__{} = state) do
    case Map.pop(state.pending, socket) do
      {nil, _pending} ->
        {:noreply, state}

      {%PendingRequest{} = request, pending} ->
        %{connection: conn, from: from, stream: stream, expiration: expiration} = request

        case Mint.HTTP.stream(conn, msg) do
          {:ok, conn, responses} ->
            if request_finished?(responses) do
              [responses | stream]
              |> Response.generate_response()
              |> reply_if_not_expired(from, expiration)

              {:noreply, %{state | pending: pending, pool: Pool.checkin(state.pool, conn)}}
            else
              request = %{request | connection: conn, stream: [responses | stream]}
              pending = Map.put(pending, socket, request)
              {:noreply, %{state | pending: pending}}
            end

          {:error, conn, reason, _responses} ->
            reply_if_not_expired({:error, reason}, from, expiration)
            {:noreply, %{state | pending: pending, pool: Pool.checkin(state.pool, conn)}}
        end
    end
  end

  def via_tuple(name, index), do: {:via, Registry, {Config.registry_name(), {name, index}}}

  defp request_finished?(responses),
    do:
      Enum.any?(responses, fn
        {:done, _} -> true
        {:error, _, _} -> true
        _ -> false
      end)

  defp reply_if_not_expired(response, to, expiration) do
    if !Utils.expired?(expiration) do
      GenServer.reply(to, response)
    end
  end
end
