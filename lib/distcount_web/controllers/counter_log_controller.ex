defmodule DistcountWeb.CounterLogController do
  @moduledoc false
  use DistcountWeb, :controller

  alias Distcount.Counters
  alias Distcount.Counters.CounterLog

  action_fallback DistcountWeb.FallbackController

  ## Controller actions

  @spec incr(Plug.Conn.t(), %{required(binary) => term}) :: Plug.Conn.t()
  def incr(conn, counter_params) when is_map(counter_params) do
    with {:ok, %CounterLog{} = log} <- CounterLog.validate(counter_params) do
      :ok = Counters.incr(log)

      conn
      |> put_status(:accepted)
      |> render("show.json", counter_log: log)
    end
  end
end
