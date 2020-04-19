defmodule Freshness.Supervisor do
  @moduledoc """
  The supervisor responsible for a pool of workers. Check the `README` for instructions on how to setup.
  """
  use DynamicSupervisor

  alias Freshness.{Config, Server}

  @spec start_link(Config.t()) ::
          :ignore | {:error, any} | {:ok, pid}
  def start_link(%Config{} = config) do
    # store a counter_ref with the supervisor. The counter will be used to
    # round robin requests to the child servers
    counter_ref = :atomics.new(1, signed: false)
    name = {:via, Registry, {Config.registry_name(), config.name, {counter_ref, config.count}}}

    case DynamicSupervisor.start_link(__MODULE__, [], name: name) do
      {:ok, pid} ->
        1..config.count |> Enum.each(fn i -> start_child(pid, %{config | index: i - 1}) end)
        {:ok, pid}

      other ->
        other
    end
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defp start_child(sup, %Config{} = config) do
    DynamicSupervisor.start_child(sup, {Server, config})
  end
end
