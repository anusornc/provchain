import Config

config :provchain,
  dag_storage_path: "data/prod/dag",
  merkle_storage_path: "data/prod/merkle",
  network_port: System.get_env("PORT", "4000") |> String.to_integer(),
  validator_timeout: 10000

config :logger,
  level: :info,
  backends: [:console]

# Import production secrets if available
if File.exists?("config/prod.secret.exs") do
  import_config "prod.secret.exs"
end
