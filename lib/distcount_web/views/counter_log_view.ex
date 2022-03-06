defmodule DistcountWeb.CounterLogView do
  @moduledoc false
  use DistcountWeb, :view
  alias DistcountWeb.CounterLogView

  def render("show.json", %{counter_log: counter_log}) do
    %{data: render_one(counter_log, CounterLogView, "counter_log.json")}
  end

  def render("counter_log.json", %{counter_log: counter_log}) do
    %{
      key: counter_log.key,
      value: counter_log.value
    }
  end
end
