defmodule Utils do
  @spec expiration(integer) :: Utils.Expiration.t()
  defdelegate expiration(timeout), to: Utils.Expiration, as: :new

  @spec expired?(Utils.Expiration.t()) :: boolean()
  defdelegate expired?(expiration), to: Utils.Expiration
end
