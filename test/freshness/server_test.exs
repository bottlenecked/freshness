defmodule Freshness.ServerTest do
  use ExUnit.Case, async: true
  doctest Freshness.Server

  alias Freshness.{Config, Pool, Server}

  setup do
    fun = fn ->
      {:ok, pid} = Server.start_link(%Config{scheme: :http, port: 80, host: "www.google.com"})
      pid
    end

    {:ok, %{pid_fun: fun}}
  end

  test "making a request to a non-existing domain returns error" do
    {:ok, pid} = Server.start_link(%Config{scheme: :http, port: 80, host: "foo.bar.baz"})
    assert {:error, %Mint.TransportError{reason: :nxdomain}} = Server.get(pid, "/")
  end

  test "responses return once finished", %{pid_fun: fun} do
    pid = fun.()

    self_pid = self()

    1..2
    |> Enum.each(fn _ ->
      spawn(fn ->
        {:ok, resp} = Server.get(pid, "/")
        send(self_pid, resp)
      end)
    end)

    assert_receive([_h | _t] = responses1, 1000)
    assert_receive([_h | _t] = responses2, 1000)

    [responses1, responses2]
    |> Enum.each(fn responses ->
      assert Enum.any?(responses, fn
               {:done, _ref} -> true
               _ -> false
             end)
    end)
  end

  test "making 2 requests in a row will use only a single connection", %{pid_fun: fun} do
    pid = fun.()
    {:ok, _resp} = Server.get(pid, "/")
    {:ok, _resp} = Server.get(pid, "/")

    %{pool: pool} = :sys.get_state(pid)

    assert Pool.length(pool) == 1
  end
end
