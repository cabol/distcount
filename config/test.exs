import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :distcount, Distcount.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "distcount_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :distcount, DistcountWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 3333],
  secret_key_base: "R45yoQy2On1wHNuUMRET164vzHPU0pYz6OZmwXImonJgAQ4logmVQ+IOiuMMqzp3",
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Time bucket aggregator
config :distcount, Distcount.Counters.TimeBucketAggregator, offload_interval: 1000
