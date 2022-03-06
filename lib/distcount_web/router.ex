defmodule DistcountWeb.Router do
  @moduledoc false
  use DistcountWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DistcountWeb do
    pipe_through :api

    post "/increment", CounterLogController, :incr
  end
end
