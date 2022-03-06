defmodule Distcount.Counters.TimeBucketAggregator do
  @moduledoc """
  Time bucket aggregator for counters.

  The main idea of this module is to aggregate counter logs by time slot, where
  the time slot is the offloading interval (interval for offloading the counter
  logs to the database to sync state).

  Since the counters are kept in memory (via an ETS table), the idea is to
  offload to the database only the counters that have been updated during the
  last offloading interval. Otherwise, we will end up having a full copy of the
  counters in memory and maybe offloading to the database some counters that
  haven't been even updated. This will be very inefficient and will affect the
  offloading performance significantly as well as it will increase the memory
  consumption very much (depending on the number of counters).

  ## Usage

  You can provide your own configuration via config file like so:

      config :distcount, Distcount.Counters.TimeBucketAggregator,
        offload_interval: 5000

  Check the available options in the `start_link/1` function.

  ## Telemetry

  This module exposes following Telemetry events:

    * `[:counters, :aggregator, :start]` - Dispatched when the process starts.

      * Measurement: `%{system_time: integer}`
      * Metadata: `%{name: atom}`

    * `[:counters, :aggregator, :stop]` - Dispatched when the process stops.

      * Measurement: `%{system_time: integer}`
      * Metadata: `%{name: atom, reason: term}`

    * `[:counters, :aggregator, :incr, :start]` - Dispatched before the `incr/3`
      function is executed.

      * Measurement: `%{system_time: integer}`
      * Metadata: `%{counter: binary, amount: integer}`

    * `[:counters, :aggregator, :incr, :stop]` - Dispatched after the `incr/3`
      function is executed.

      * Measurement: `%{duration: integer}`
      * Metadata: `%{counter: binary, amount: integer}`

    * `[:counters, :aggregator, :incr, :exception]` - This event should be
      invoked when an error or exception occurs while executing the `incr/3`
      function.

      * Measurement: `%{duration: integer}`
      * Metadata:

        ```
        %{
          counter: binary,
          amount: integer,
          kind: :error | :exit | :throw,
          reason: term,
          stacktrace: term
        }
        ```

    * `[:counters, :aggregator, :offload, :start]` - Dispatched before the
      offloading process is executed.

      * Measurement: `%{system_time: integer}`
      * Metadata: `%{state: state}`

    * `[:counters, :aggregator, :offload, :stop]` - Dispatched after the
      offloading process is executed.

      * Measurement: `%{duration: integer}`
      * Metadata: `%{state: state}`

    * `[:counters, :aggregator, :offload, :exception]` - This event should be
      invoked when an error or exception occurs while executing the offloading.

      * Measurement: `%{duration: integer}`
      * Metadata:

        ```
        %{
          state: state,
          kind: :error | :exit | :throw,
          reason: term,
          stacktrace: term
        }
        ```

    * `[:counters, :aggregator, :offloaded_logs]` - Dispatched after inserting
      the counter logs (offloading process).

      * Measurement: `%{system_time: integer}`
      * Metadata: `%{inserted: integer, state: state}`

  """

  use GenServer

  alias Distcount.Counters.CounterLog
  alias Distcount.Repo

  require Logger

  # Internal state
  defstruct name: nil,
            pid: nil,
            tid: nil,
            start_time: nil,
            offload_timer_ref: nil,
            offload_interval: 10_000

  @typedoc "Type for internal state"
  @type state :: %__MODULE__{
          name: atom | nil,
          pid: pid | nil,
          tid: :ets.tid() | nil,
          start_time: non_neg_integer | nil,
          offload_timer_ref: :timer.tref() | nil,
          offload_interval: non_neg_integer
        }

  opts_definition = [
    name: [
      type: :atom,
      required: false
    ],
    offload_interval: [
      type: :pos_integer,
      required: false,
      default: 10_000
    ]
  ]

  # NimbleOptions definition
  @opts_definition NimbleOptions.new!(opts_definition)

  # Telemetry prefix
  @telemetry_prefix [:counters, :aggregator]

  @doc """
  Starts a new server for the time-bucket defined by the given options `opts`.

  ## Options

    * `:name` - An atom defining the name of the server. Defaults `__MODULE__`.

    * `:offload_interval` - Offloading interval in milliseconds (Defaults to
      `10_000` - 10 sec).

  ## Example

      Distcount.Counters.TimeBucketAggregator.start_link(name: :test)

  """
  @spec start_link(opts :: keyword) :: GenServer.on_start()
  def start_link(opts \\ []) do
    # Validate the given options
    opts = NimbleOptions.validate!(opts, @opts_definition)

    # GenServer options
    server_opts = if name = Keyword.get(opts, :name, __MODULE__), do: [name: name], else: []

    GenServer.start_link(__MODULE__, opts, server_opts)
  end

  @doc """
  Increments/decrements the `counter` by the given `amount`.

  ## Example

      Distcount.Counters.TimeBucketAggregator.incr(:test, "counter", 1)

  """
  @spec incr(name_or_pid :: atom | pid, counter :: binary, amount :: pos_integer) :: pos_integer
  def incr(name_or_pid, counter, amount)

  def incr(name, counter, amount) when is_atom(name) do
    name
    |> GenServer.whereis()
    |> Kernel.||(
      raise "cound not find #{inspect(name)} because it was not started or it does not exist"
    )
    |> incr(counter, amount)
  end

  def incr(pid, counter, amount) when is_pid(pid) and is_binary(counter) and is_integer(amount) do
    event_metadata = %{counter: counter, amount: amount}

    :telemetry.span(@telemetry_prefix ++ [:incr], event_metadata, fn ->
      result =
        with_meta(pid, fn {tid, offload_interval} ->
          counter_k = {time_slot(offload_interval), counter}

          :ets.update_counter(tid, counter_k, amount, {counter_k, 0})
        end)

      {result, event_metadata}
    end)
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    # Trap exit signals to ensure a graceful shutdown and proper cleanup
    _ = Process.flag(:trap_exit, true)

    # Retrieve the process name (if any)
    name = Keyword.fetch!(opts, :name)

    # ETS table for storing/updating the counters by time slot
    # (same offloading interval) so that we offload to the
    # database only the counters updated during the last
    # offloading interval (and before)
    tid =
      :ets.new(name, [
        :set,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])

    # Add extra options
    opts =
      opts
      |> Keyword.put(:name, name)
      |> Keyword.put(:pid, self())
      |> Keyword.put(:tid, tid)
      |> Keyword.put(:offload_timer_ref, gc_reset(Keyword.fetch!(opts, :offload_interval)))
      |> Keyword.put(:start_time, now())

    # Build initial server state
    state = struct(__MODULE__, :maps.from_list(opts))

    # We use the `:persistent_term` to store metadata, like the offload interval
    # in this case. To have much better performance and scalability, we want
    # to retrieve this data without calling the server/process itself to
    # retrieve from process's state, avoiding a single-process bottleneck.
    # We could use also the same ETS, but let's assume this parameters are not
    # going to be changed once the app starts (loaded in config-time).
    # If runtime changes are needed because this parameter will change very
    # often, then the implementation will change and ETS will make more sense
    # (See `:persistent_term` docs for more info).
    :ok = :persistent_term.put({self(), :metadata}, {state.tid, state.offload_interval})

    # Dispatch start event
    :ok = dispatch_telemetry_event([:start], %{name: name})

    {:ok, state}
  end

  @impl true
  def handle_info(message, state)

  def handle_info(:offload_timeout, state) do
    {:noreply, run_offload(state)}
  end

  def handle_info({:EXIT, pid, reason}, %__MODULE__{pid: pid} = state) do
    {:stop, reason, state}
  end

  @impl true
  def terminate(reason, state) do
    # Run offloading (force to dump all counters in the table)
    _ = run_offload(%{state | offload_interval: 0})

    # Dispatch stop event
    :ok = dispatch_telemetry_event([:stop], %{reason: reason, name: state.name})

    # Cleanup metadata
    _ = :persistent_term.erase({state.name, :metadata})
  end

  ## Private Functions

  # Inline common instructions
  @compile {:inline, now: 0}

  defp now, do: System.system_time(:millisecond)

  defp time_slot(0), do: nil
  defp time_slot(slot_size), do: trunc(now() / slot_size) * slot_size

  defp with_meta(pid, fun) do
    {pid, :metadata}
    |> :persistent_term.get()
    |> fun.()
  end

  defp run_offload(state) do
    # Measure the DB offload duration
    :telemetry.span(@telemetry_prefix ++ [:offload], %{state: state}, fn ->
      state = offload_counters(state)

      {state, %{state: state}}
    end)
  end

  defp offload_counters(%__MODULE__{tid: tid, offload_interval: interval} = state) do
    # Fix the table for safe traversal (See `:ets.safe_fixtable/2`)
    true = :ets.safe_fixtable(tid, true)

    # Get the current time slot
    current_slot = time_slot(interval)

    # Traverse the table for collecting the updated counters
    # before the last offloading interval run
    {keys, logs} =
      fn
        {{slot, counter} = key, value}, {keys, logs} when slot < current_slot ->
          {[key | keys], [counter_attrs(counter, value) | logs]}

        _rec, acc ->
          acc
      end
      |> :ets.foldl({[], []}, tid)

    # Dump the counter logs into the database
    # TODO: Maybe do some chunking instead of insert all records at once,
    #       we can do it in batches too (evaluate the alternative)
    {inserted, _result} = Repo.insert_all(CounterLog, logs)

    # Delete the processed counters
    :ok = Enum.each(keys, &:ets.delete(tid, &1))

    # Telemetry event
    if inserted > 0 do
      :ok = dispatch_telemetry_event([:offloaded_logs], %{inserted: inserted, state: state})
    end

    # Update state (reset timer)
    %{state | offload_timer_ref: gc_reset(interval)}
  after
    # Release the table (See `:ets.safe_fixtable/2`)
    true = :ets.safe_fixtable(tid, false)
  end

  defp counter_attrs(key, value) do
    dt = %{NaiveDateTime.utc_now() | microsecond: {0, 0}}

    %{key: key, value: value, inserted_at: dt, updated_at: dt}
  end

  defp gc_reset(timeout) do
    {:ok, timer_ref} = :timer.send_after(timeout, :offload_timeout)

    timer_ref
  end

  defp dispatch_telemetry_event(event, measurements \\ %{}, metadata) do
    :telemetry.execute(
      @telemetry_prefix ++ event,
      Map.put_new_lazy(measurements, :system_time, &System.system_time/0),
      metadata
    )
  end
end
