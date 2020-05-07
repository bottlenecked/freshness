defmodule Utils.ExpirationTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Utils.Expiration

  property "timeout is always expired when enough time has passed" do
    check all(
            since <- positive_integer(),
            timeout <- positive_integer(),
            current <- positive_integer()
          ) do
      since_dt = DateTime.from_unix!(since, :millisecond)
      current_dt = DateTime.from_unix!(current, :millisecond)
      expiration = Expiration.new(timeout, since_dt)

      expired? = Expiration.expired?(expiration, current_dt)

      if since + timeout > current do
        assert !expired?
      else
        assert expired?
      end
    end
  end
end
