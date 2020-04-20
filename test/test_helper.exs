ExUnit.start(colors: [enabled: true])

Supervisor.start_link(
  [
    {Registry, keys: :unique, name: Freshness.Config.registry_name()}
  ],
  strategy: :one_for_one
)
