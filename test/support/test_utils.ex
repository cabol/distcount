defmodule Distcount.TestUtils do
  @moduledoc false

  ## API

  @spec wait_until(pos_integer, pos_integer, fun) :: term
  def wait_until(retries \\ 50, delay \\ 100, fun)

  def wait_until(1, _delay, fun), do: fun.()

  def wait_until(retries, delay, fun) when retries > 1 do
    fun.()
  rescue
    _ ->
      :ok = Process.sleep(delay)
      wait_until(retries - 1, delay, fun)
  end

  @spec with_telemetry_handler(term, list([atom]), fun) :: term
  def with_telemetry_handler(handler_id \\ __MODULE__, events, fun) do
    :ok =
      :telemetry.attach_many(
        handler_id,
        events,
        &__MODULE__.handle_event/4,
        %{pid: self()}
      )

    fun.()
  after
    :telemetry.detach(handler_id)
  end

  @doc false
  def handle_event(event, measurements, metadata, %{pid: pid}) do
    send(pid, {event, measurements, metadata})
  end
end
