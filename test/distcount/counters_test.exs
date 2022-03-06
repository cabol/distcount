defmodule Distcount.CountersTest do
  use Distcount.DataCase

  alias Distcount.Counters

  describe "counters" do
    alias Distcount.Counters.CounterLog

    import Distcount.CountersFixtures

    @invalid_attrs %{key: nil, value: nil}

    test "create_counter_log/1 with valid data creates a counter" do
      valid_attrs = %{key: "counter", value: 0}

      assert {:ok, %CounterLog{} = log} = Counters.create_counter_log(valid_attrs)
      assert log.key == "counter"
      assert log.value == 0
    end

    test "create_counter_log/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Counters.create_counter_log(@invalid_attrs)
    end

    test "get_counter_value/1 returns the counter value with given key" do
      counter = counter_fixture()
      key = counter.key

      assert Counters.get_counter_value(key) == 0
      refute Counters.get_counter_value("unknown")

      :ok = Enum.each(1..3, &counter_fixture(%{value: &1}))

      assert Counters.get_counter_value(key) == 6
      refute Counters.get_counter_value("unknown")
    end
  end
end
