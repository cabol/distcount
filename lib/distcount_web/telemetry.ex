defmodule DistcountWeb.Telemetry do
  @moduledoc """
  Telemetry metrics.

  ## Usage

  In your config file add:

      config :distcount, DistcountWeb.Telemetry,
        telemetry_metrics: [
          reporter: Telemetry.Metrics.ConsoleReporter
        ]

  Where the option `:telemetry_metrics` will define the reporter and the options
  for it.

  > **NOTE:** No reporter is configured by default.

  For example, if you want to use StatsD as reporter (e.g.: with Datadog):

      config :distcount, DistcountWeb.Telemetry,
        telemetry_metrics: [
          reporter: TelemetryMetricsStatsd,
          formatter: :datadog,
          prefix: "distcount",
          global_tags: [otp_app: "distcount", env: "dev"],
          host: "127.0.0.1",
          port: 8125,
          pool_size: 10
        ]

  See `TelemetryMetricsStatsd` for more information about the supported options.
  """

  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      | telemetry_metrics_specs()
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp telemetry_metrics_specs do
    config = Application.get_env(:distcount, __MODULE__, [])
    telemetry_metrics = Keyword.get(config, :telemetry_metrics, [])

    case Keyword.pop(telemetry_metrics, :reporter) do
      {nil, _telemetry_metrics} ->
        []

      {reporter, telemetry_metrics} ->
        [{reporter, [metrics: metrics()] ++ telemetry_metrics}]
    end
  end

  defp metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("distcount.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("distcount.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("distcount.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("distcount.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("distcount.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # App Metrics
      summary("counters.aggregator.incr.stop.duration",
        unit: {:native, :millisecond},
        tags: [:counter, :amount]
      ),
      summary("counters.aggregator.offload.stop.duration",
        unit: {:native, :millisecond},
        tags: [:name],
        tag_values: &%{name: &1.state.name}
      ),
      counter("counters.aggregator.offloaded_logs.system_time",
        tags: [:inserted, :name],
        tag_values: &Map.put(&1, :name, &1.state.name)
      ),
      counter("counters.aggregator.start.system_time", tags: [:name]),
      counter("counters.aggregator.stop.system_time",
        tags: [:name, :reason],
        tag_values: &Map.put(&1, :reason, inspect(&1.reason))
      )
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {DistcountWeb, :count_users, []}
    ]
  end
end
