defmodule Freshness.PoolTest do
  # These tests require an internet connection to run correctly

  use ExUnit.Case, async: true
  alias Freshness.Pool
  doctest Pool

  setup do
    bad_pool = Pool.new(:http, "foo.bar.baz", 80)
    good_pool = Pool.new(:http, "google.com", 80)
    {:ok, %{good_pool: good_pool, bad_pool: bad_pool}}
  end

  test "pool reports empty?/1 and length/1 correctly", %{good_pool: pool} do
    assert Pool.empty?(pool)
    assert Pool.length(pool) == 0

    # create a new connection and check in
    {:ok, pool, conn} = Pool.checkout(pool)
    pool = Pool.checkin(pool, conn)

    assert !Pool.empty?(pool)
    assert Pool.length(pool) == 1
  end

  test "trying to get pool for bad domain returns error", %{bad_pool: pool} do
    assert {:error, %Mint.TransportError{reason: :nxdomain}} = Pool.checkout(pool)
  end

  test "checking in and then out a connection will return it last", %{good_pool: pool} do
    # create 2 new connections
    {:ok, pool, conn1} = Pool.checkout(pool)
    {:ok, pool, conn2} = Pool.checkout(pool)

    # add them back in order
    pool = Pool.checkin(pool, conn1)
    pool = Pool.checkin(pool, conn2)

    assert Pool.length(pool) == 2

    # next checkout should return the fist connection
    {:ok, pool, conn} = Pool.checkout(pool)

    assert conn == conn1
    assert Pool.length(pool) == 1
  end

  test "cannot check in a closed connection", %{good_pool: pool} do
    {:ok, pool, conn} = Pool.checkout(pool)
    {:ok, conn} = Mint.HTTP.close(conn)
    pool = Pool.checkin(pool, conn)

    assert Pool.empty?(pool)
  end
end
