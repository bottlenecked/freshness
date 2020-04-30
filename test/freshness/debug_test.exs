defmodule Freshness.DebugTest do
  use ExUnit.Case, async: true
  alias Freshness.Config

  setup do
    name = :apachedebug
    config = Config.new(name, 3, :http, "www.apache.org", 80)
    Freshness.Supervisor.start_link(config)

    {:ok, %{name: name}}
  end

  test "connection_count counts connections correctly", %{name: name} do
    # no calls made yet, connection count should be 0
    assert Freshness.Debug.connection_count(name) == 0

    # make a request, make sure count == 1
    Freshness.get(name, "/")
    assert Freshness.Debug.connection_count(name) == 1
  end
end
