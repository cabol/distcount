# Distcount
> Counters app example!

This is a simple example of how to implement an app or service for
incrementing counters, as well as persisting them somehow. It uses
ETS tables for implementing "time bucketing aggregation" for being
able to update and aggregate the counters by time slots allowing
max writes concurrency. It also uses PorstgreSQL for persisting
the state. The counters state is persisted as an event log to
improve the sync/offloading process.

## Getting started

To start the app:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can call the endpoint to increment counters using `curl`, like so:

```
curl -iX POST 'http://localhost:3333/increment' \
  -H 'content-type: application/json' \
  -d '{"key": "c1", "value": 1}'
```

From the IEx you can also check the actual counter value by calling:

```elixir
iex> Distcount.Counters.get_counter_value("c1")
1
```

> **NOTE:** Keep in mind the offload interval time.

### Configuring the sync/offloading interval

You can set any offloading interval by configuring the
`Distcount.Counters.TimeBucketAggregator`, for example
in the config file:

```elixir
# Time bucket aggregator
config :distcount, Distcount.Counters.TimeBucketAggregator,
  offload_interval: 5000
```

## Telemetry Metrics

This projects is instrumented by means of `Telemetry` and `TelemetryMetrics`.
You can find the dispatched metrics in the module `DistcountWeb.Telemetry`.
We basically dispatch the different metrics provided by `Phoenix`, `Ecto`,
and `:telemetry_poller`, as well and the ones provided by the app `Distcount`
itself; you can find more information about these metrics in the module
`Distcount.Counters.TimeBucketAggregator` (see Telemetry section in the docs).

For validating the metrics, you can run the app in `dev` mode inside IEx and all
the metrics will me printed there, since the Telemetry console reporter is
enabled in `dev`. Try calling the endpoint so you can see the metrics dispatched
by the app. Also you will see the ones related to the offload.sync process.

Additionally, since the project uses the Telemetry stack, you can change the
reporter at any time and point the metrics to a StatsD agent for example and
send them to some tool like Datadog. See `DistcountWeb.Telemetry` docs, there
is an example about how to configure the StatsD reporter.

## Testing

For running the unit tests:

```
mix test
```

Running the tests with coverage:

```
mix coveralls.html
```

You will find the coverage report within `cover/excoveralls.html`.

Additionally, you can run all the checks by running:

```
mix check
```

## Benchmarks

This project provides a set of basic benchmark tests using the library
[benchee][benchee], and they are located within the directory
[benchmarks](./benchmarks).

Since we use a specific profile for the benchmarks, you have to setup the DB
first:

```
MIX_ENV=bench mix ecto.create
MIX_ENV=bench mix ecto.migrate
```

To run a benchmark test you have to run:

```
MIX_ENV=bench mix run benchmarks/distcount_bench.exs
```

> **NOTE:** The `MIX_ENV=bench` is for running the bench with `bench` profile
  and avoid the logs and metrics (Telemetry console reporter) enabled in `dev`
  and printed in the console.

You can also tweak the bench based on [benchee][benchee] options.

[benchee]: https://github.com/PragTob/benchee

There are two operations we measure here: `Distcount.Counters.incr/1` and
`Distcount.Counters.get_counter_value/1`. this give us an idea about the
performance of incrementing counters (writes) as well as retrieving them
(reads); despite the project is mainly focused on writes.
