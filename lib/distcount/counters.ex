defmodule Distcount.Counters do
  @moduledoc """
  The Counters context.
  """

  import Ecto.Query, warn: false

  alias Distcount.Repo

  alias Distcount.Counters.{CounterLog, TimeBucketAggregator}

  @typedoc "Type for write operations response"
  @type wr_response :: {:ok, CounterLog.t()} | {:error, Ecto.Changeset.t()}

  ## API

  @doc """
  Creates a counter.

  ## Examples

      iex> create_counter_log(%{field: value})
      {:ok, %Distcount.Counters.CounterLog{}}

      iex> create_counter_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_counter_log(map) :: wr_response
  def create_counter_log(attrs \\ %{}) do
    %CounterLog{}
    |> CounterLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets the counter's value given by `key`.

  ## Examples

      iex> get_counter_value("counter")
      0

      iex> get_counter_value("unknown")
      nil

  """
  @spec get_counter_value(binary) :: CounterLog.t() | nil
  def get_counter_value(key) when is_binary(key) do
    from(cl in CounterLog, where: cl.key == ^key)
    |> Repo.aggregate(:sum, :value)
  end

  @doc """
  Increments/decrements the `counter`.

  ## Example

      iex> incr(%Distcount.Counters.CounterLog{key: "foo", value: 1})
      :ok

  """
  @spec incr(CounterLog.t()) :: :ok
  def incr(%CounterLog{key: key, value: value}) do
    _ = TimeBucketAggregator.incr(__MODULE__, key, value)

    :ok
  end
end
