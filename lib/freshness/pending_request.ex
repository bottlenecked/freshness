defmodule Freshness.PendingRequest do
  defstruct [
    :from,
    :connection,
    stream: []
  ]
end
