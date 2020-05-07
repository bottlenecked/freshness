defmodule Freshness.ServerTest do
  use ExUnit.Case, async: true
  doctest Freshness.Server

  alias Freshness.{Config, Pool, Server, Response}
  alias Freshness.Config.MintConfig

  setup do
    fun = fn ->
      {:ok, pid} =
        Server.start_link(%Config{
          mint: %MintConfig{scheme: :http, port: 80, host: "www.apache.org"}
        })

      pid
    end

    {:ok, %{pid_fun: fun}}
  end

  test "making a request to a non-existing domain returns error" do
    {:ok, pid} =
      Server.start_link(%Config{mint: %MintConfig{scheme: :http, port: 80, host: "foo.bar.baz"}})

    assert {:error, %Mint.TransportError{reason: :nxdomain}} = Server.request(pid, "GET", "/")
  end

  test "responses return once finished", %{pid_fun: fun} do
    pid = fun.()

    self_pid = self()

    1..2
    |> Enum.each(fn _ ->
      spawn(fn ->
        {:ok, resp} = Server.request(pid, "GET", "/")
        send(self_pid, resp)
      end)
    end)

    assert_receive(%Response{} = response1, 1000)
    assert_receive(%Response{} = response2, 1000)
  end

  test "making 2 requests in a row will use only a single connection", %{pid_fun: fun} do
    pid = fun.()
    {:ok, _resp} = Server.request(pid, "GET", "/")
    {:ok, _resp} = Server.request(pid, "GET", "/")

    %{pool: pool} = :sys.get_state(pid)

    assert Pool.length(pool) == 1
  end

  test "status, headers and body are all there for large responses", %{pid_fun: fun} do
    pid = fun.()
    {:ok, resp} = Server.request(pid, "GET", "/")

    assert %{
             status: 200,
             headers: headers,
             data: data
           } = resp

    assert Enum.any?(headers, fn
             {"content-type", "text/html"} -> true
             _ -> false
           end)

    assert length(data) > 0
  end

  test "timeout is respected and no ghost replies are received", %{pid_fun: fun} do
    pid = fun.()
    # using a very small timeout value
    response = Server.request(pid, "GET", "/", [], "", timeout: 10)
    assert response == {:error, :timeout}
    # also make sure no ghost replies reach us after the timeout
    refute_receive(_any, 500)
  end
end
