defmodule Freshness.Config.MintConfig do
  @moduledoc """
  Mint connection configuration options
  """
  @type t() :: %__MODULE__{}

  defstruct [
    :scheme,
    :port,
    :host,
    options: []
  ]
end
