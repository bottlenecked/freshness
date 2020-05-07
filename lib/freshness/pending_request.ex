defmodule Freshness.PendingRequest do
  defstruct [
    :from,
    :connection,
    :expiration,
    stream: []
  ]
end
