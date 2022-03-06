defmodule Distcount.Counters.TimeBucketAggregatorTest do
  use Distcount.DataCase

  import Distcount.TestUtils

  alias Distcount.Counters
  alias Distcount.Counters.TimeBucketAggregator

  # Telemetry
  @prefix [:counters, :aggregator]
  @start @prefix ++ [:start]
  @stop @prefix ++ [:stop]
  @incr_start @prefix ++ [:incr, :start]
  @incr_stop @prefix ++ [:incr, :stop]
  @offload_start @prefix ++ [:offload, :start]
  @offload_stop @prefix ++ [:offload, :stop]
  @offloaded_logs @prefix ++ [:offloaded_logs]
  @events [@start, @stop, @incr_start, @incr_stop, @offload_start, @offload_stop, @offloaded_logs]

  describe "incr/3" do
    test "ok: counter is incremented by the given amount" do
      with_aggregator(fn _pid ->
        assert TimeBucketAggregator.incr(__MODULE__, "c0", 1) == 1

        assert_incr_start("c0", 1)
        assert_incr_stop("c0", 1)

        assert TimeBucketAggregator.incr(__MODULE__, "c0", 2) == 3

        assert_incr_start("c0", 2)
        assert_incr_stop("c0", 2)

        assert TimeBucketAggregator.incr(__MODULE__, "c0", -1) == 2

        assert_incr_start("c0", -1)
        assert_incr_stop("c0", -1)
      end)
    end

    test "ok: updated counters are offloaded to the database" do
      with_aggregator([offload_interval: 200], fn _pid ->
        :ok = Enum.each(1..3, &TimeBucketAggregator.incr(__MODULE__, "c#{&1}", &1 * 2))
        :ok = Enum.each(1..3, &TimeBucketAggregator.incr(__MODULE__, "c#{&1}", &1 * 2))

        assert_offload_start()
        assert_offloaded_logs(inserted: 3)
        assert_offload_stop()

        assert Counters.get_counter_value("c1") == 4
        assert Counters.get_counter_value("c2") == 8
        assert Counters.get_counter_value("c3") == 12

        :ok = Enum.each(1..5, &TimeBucketAggregator.incr(__MODULE__, "c#{&1}", &1 * 2))
        :ok = Enum.each(4..5, &TimeBucketAggregator.incr(__MODULE__, "c#{&1}", &1 * 2))

        assert_offload_start()
        assert_offloaded_logs(inserted: 5)
        assert_offload_stop()

        assert Counters.get_counter_value("c1") == 6
        assert Counters.get_counter_value("c2") == 12
        assert Counters.get_counter_value("c3") == 18
        assert Counters.get_counter_value("c4") == 16
        assert Counters.get_counter_value("c5") == 20
      end)
    end

    test "error: the given process name doesn't exist " do
      assert_raise RuntimeError, ~r"cound not find :unknown", fn ->
        TimeBucketAggregator.incr(:unknown, "c0", 1)
      end
    end
  end

  describe "c:terminate/2" do
    test "invoked because EXIT signal" do
      with_telemetry_handler(__MODULE__, @events, fn ->
        _ = Process.flag(:trap_exit, true)

        {:ok, pid} = TimeBucketAggregator.start_link(name: :aggregator_exit)

        assert TimeBucketAggregator.incr(pid, "c10", 1) == 1

        _ = send(pid, {:EXIT, pid, :error})

        assert_offloaded_logs(inserted: 1, name: :aggregator_exit)

        assert Counters.get_counter_value("c10") == 1
      end)
    end
  end

  describe "offloading" do
    test "only offloads to the database the counters < current time slot" do
      with_aggregator([offload_interval: 1000], fn pid ->
        assert TimeBucketAggregator.incr(pid, "c11", 1) == 1

        _ = send(pid, :offload_timeout)

        refute_receive {@offloaded_logs, %{system_time: _}, _}
        refute Counters.get_counter_value("c11")

        assert_offload_start()
        assert_offloaded_logs(inserted: 1)
        assert_offload_stop()

        assert Counters.get_counter_value("c11") == 1
      end)
    end
  end

  ## Private Functions

  defp with_aggregator(opts \\ [], fun) do
    with_telemetry_handler(__MODULE__, @events, fn ->
      {:ok, pid} =
        opts
        |> Keyword.put_new(:name, __MODULE__)
        |> Keyword.put_new(:offload_interval, 10_000)
        |> TimeBucketAggregator.start_link()

      assert_receive {@start, %{system_time: _}, _meta}, 5000

      try do
        fun.(pid)
      after
        if Process.alive?(pid) do
          :ok = GenServer.stop(pid)
        end

        assert_receive {@stop, %{system_time: _}, _meta}, 5000
      end
    end)
  end

  defp assert_incr_start(counter, amount) do
    assert_receive {@incr_start, %{system_time: _}, meta}, 5000
    assert meta[:counter] == counter
    assert meta[:amount] == amount
  end

  defp assert_incr_stop(counter, amount) do
    assert_receive {@incr_stop, %{duration: _}, meta}, 5000
    assert meta[:counter] == counter
    assert meta[:amount] == amount
  end

  defp assert_offload_start(opts \\ []) do
    assert_receive {@offload_start, %{system_time: _}, meta}, 5000
    assert meta[:state].name == Keyword.get(opts, :name, __MODULE__)
  end

  defp assert_offload_stop(opts \\ []) do
    assert_receive {@offload_stop, %{duration: _}, meta}, 5000
    assert meta[:state].name == Keyword.get(opts, :name, __MODULE__)
  end

  defp assert_offloaded_logs(opts) do
    assert_receive {@offloaded_logs, %{system_time: _}, meta}, 5000
    assert meta[:state].name == Keyword.get(opts, :name, __MODULE__)
    assert meta[:inserted] == Keyword.fetch!(opts, :inserted)
  end
end
