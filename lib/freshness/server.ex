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
          body :: iodata() | nil | :stream
        ) ::
          {:ok, Response.t()}
          | {:error, term()}
  def request(server, method, path, headers \\ [], body \\ "") do
    GenServer.call(server, {:request, method, path, headers, body})
  end

  @impl true
  def handle_call({:request, method, path, headers, body}, from, %{pool: pool} = state) do
    with {:checkout, {:ok, pool, conn}} <- {:checkout, Pool.checkout(pool)},
         request_result = Mint.HTTP.request(conn, method, path, headers, body),
         {:request, {:ok, conn, _request_ref}} <- {:request, request_result} do
      request = %PendingRequest{connection: conn, from: from}
      pending = Map.put(state.pending, conn.socket, request)
      {:noreply, %{state | pending: pending, pool: pool}}
    else
      {:checkout, error} -> {:reply, error, state}
      {:request, {:error, _http, reason}} -> {:reply, {:error, reason}, state}
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
        %{connection: conn, from: from, stream: stream} = request

        case Mint.HTTP.stream(conn, msg) do
          {:ok, conn, responses} ->
            if request_finished?(responses) do
              response = Response.generate_response([responses | stream])
              GenServer.reply(from, response)
              {:noreply, %{state | pending: pending, pool: Pool.checkin(state.pool, conn)}}
            else
              request = %{request | connection: conn, stream: [responses | stream]}
              pending = Map.put(pending, socket, request)
              {:noreply, %{state | pending: pending}}
            end

          {:error, conn, reason, _responses} ->
            GenServer.reply(from, {:error, reason})
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
end
