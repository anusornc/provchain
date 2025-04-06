import Config

# Common configuration used across all environments
config :provchain,
  namespace: ProvChain,
  ecto_repos: []

# Environment-specific configurations
import_config "#{config_env()}.exs"
