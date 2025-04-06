import Config

# Optional runtime configuration that can override
# any configuration loaded so far
if config_env() == :prod do
  # Example for fetching values from environment
  config :provchain,
    validator_timeout: System.get_env("VALIDATOR_TIMEOUT", "10000") |> String.to_integer()
end
