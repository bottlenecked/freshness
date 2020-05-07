defmodule Utils.Expiration do
  @type milliseconds :: non_neg_integer()
  @type t() :: %__MODULE__{
          since: DateTime.t(),
          timeout: milliseconds()
        }

  defstruct [
    :since,
    :timeout
  ]

  @spec new(integer) :: Expiration.t()
  def new(timeout), do: new(timeout, DateTime.utc_now())

  @spec new(integer, DateTime.t()) :: Expiration.t()
  def new(timeout, %DateTime{} = since) when is_integer(timeout),
    do: %__MODULE__{
      timeout: timeout,
      since: since
    }

  @spec expired?(Utils.Expiration.t()) :: boolean
  def expired?(expiration), do: expired?(expiration, DateTime.utc_now())

  @spec expired?(Utils.Expiration.t(), DateTime.t()) :: boolean()
  def expired?(%__MODULE__{since: since, timeout: timeout}, %DateTime{} = current) do
    comparison =
      since
      |> DateTime.add(timeout, :millisecond)
      |> DateTime.compare(current)

    comparison != :gt
  end
end
