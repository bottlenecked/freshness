# Freshness

[![Hex.pm](https://img.shields.io/hexpm/v/freshness.svg)](https://hex.pm/packages/freshness)

A minimal pooling wrapper on top of [Mint](https://github.com/elixir-mint/mint).
It is meant as an alternative pooling option (other than e.g. [Mojito](https://github.com/appcues/mojito)) that should in theory allow for more flexibility when using Mint options. It returns raw Mint responses back to callers.

## Installation

Install the package by adding `:freshness` to your list of dependencies in `mix.exs`. If you need to make https requests then you need to add the `castore` dependency too (as with Mint)

```elixir
def deps do
  [
    {:castore, "~> 0.1.0"},
    {:freshness, "~> 0.3"}
  ]
end
```

## How to use
Freshness needs an `Registry` to look up workers. For each additional destination you need make requests to you need to add an additional supervisor to handle them.

Add the following lines to your application.ex file (or under any other `Supervisor` you want).<br>
You can also take a look at the [Mint connection options](https://hexdocs.pm/mint/Mint.HTTP.html#connect/4-options)

```elixir
def start (_, _) do

  # create 2 different pools for 2 separate endpoints
  # name can be any term, and will be used to identify the correct pool

  # arguments are pool_name, no_of_workers_in_pool, scheme, domain, port, mint_connection_options
  config = Freshness.Config.new("google", 5, :http, "google.com", 80, [])
  config2 = Freshness.Config.new(:bing, 5, :http, "bing.com", 80)

  children = [
    # freshness expect to find a :unique registry named Registry.Freshness. If you are already
    # using the Registry module in your app, you will need to specify an id as follows:

    Supervisor.child_spec({Registry, keys: :unique, name: Freshness.Config.registry_name()},
      id: Freshness.Config.registry_name()
    ),

    # again, because we're specifying the Freshness.Supervisor module twice, we need to also provide a distinct id

    Supervisor.child_spec({Freshness.Supervisor, config}, id: config1.name),
    Supervisor.child_spec({Freshness.Supervisor, config2}, id: config2.name)
  ]
  ...
  Supervisor.start_link(children, strategy: :one_for_one)
end
```

Inside your application you can now issue requests to the configured endpoints

```elixir
{:ok, %Freshness.Response{}} = Freshness.get("google", "/")
...
{:ok, %Freshness.Response{}} = Freshness.get(:bing, "/")
```

### Request options
The following request options are supported (different than Mint connection options)
* `:timeout`: Request timeout in milliseconds. If timeout expires the response will be `{:error, :timeout}`. If no timeout value is given, the default `GenServer.call/3` timeout value of 5000 applies

You can pass those options as the last parameter in `Freshness.get/4` and `Freshness.request/6`

```elixir
{:ok, %Freshness.Response{}} = Freshness.get("google", "/", [], timeout: 1000)
```

### Debugging
Using the `Freshness.Debug` module you can get the total count for all open connections
```elixir
# e.g. for a Freshness pool named :google
iex> Freshness.Debug.connection_count(:google)
12
```
_Note_: the debug functions can adversely affect the performance of a live system under load, make sure they are not called too often in production (they work by issueing `:sys.get_state/1` messages to the workers in the pool)

### Advanced usage
If you do not know the destinations at runtime, you can start the Registry in your application.ex file as above, but start the Freshness.Supervisors under a DynamicSupervisor

## How it works
Freshness works by creating pools of workers that each holds one or more connections to a given destination. Freshness discovers the worker to pass a request to using the `Registry` module and an `:atomics` counter to round robin the requests to each worker in the pool. Connecting and HTTP1,2 protocol parsing and buffering are all Mint.

__GOTCHA__: Connections are opened lazily and re-used, but more may be created on the spot if a given worker cannot satisfy a request. Right now the number of open connections each worker can open is unbound.

## Is this production ready?
Not by a long shot. It's barely tested. Perhaps it will be someday- right now it just serves as an exploration project.

