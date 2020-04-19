defmodule Freshness.Config do
  @moduledoc """
  Freshness configuration options
  """

  alias Freshness.Config.MintConfig

  @type pool_name :: any()

  @typedoc """
  __name__: the name to register a freshness tree under. Used with `Elixir.Registry` to address open connections to a perticular endpoint.<br>
  __count__: number of servers in the pool<br>
  __index__: the i-th process to register under this name<br>
  __mint__: Mint configuration options for opening connections (scheme, port, host, options)<br>
  """
  @type t() :: %__MODULE__{
          name: pool_name(),
          count: pos_integer(),
          index: non_neg_integer(),
          mint: MintConfig.t()
        }

  defstruct [
    :name,
    :count,
    :index,
    :mint
  ]

  @registry_name Registry.Freshness

  @spec registry_name :: atom()
  def registry_name(), do: @registry_name

  @spec new(
          pool_name(),
          pos_integer(),
          Mint.Types.scheme(),
          String.t(),
          :inet.port_number(),
          keyword()
        ) :: t()
  def new(name, count, scheme, host, port, options \\ []),
    do: %__MODULE__{
      name: name,
      count: count,
      index: 0,
      mint: %MintConfig{
        scheme: scheme,
        port: port,
        host: host,
        options: options
      }
    }
end
