defmodule Distcount.CountersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Distcount.Counters` context.
  """

  alias Distcount.Counters

  @doc """
  Generate a counter.
  """
  def counter_fixture(attrs \\ %{}) do
    {:ok, counter} =
      attrs
      |> Enum.into(%{
        key: "counter",
        value: 0
      })
      |> Counters.create_counter_log()

    counter
  end
end
