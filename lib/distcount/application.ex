defmodule Distcount.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias DistcountWeb.Endpoint

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Distcount.Repo,
      # Start the Telemetry supervisor
      DistcountWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Distcount.PubSub},
      # Start the Endpoint (http/https)
      DistcountWeb.Endpoint,
      # The time bucket aggregator for counters
      time_bucket_aggregator_spec()
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Distcount.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end

  ## Private Functions

  defp time_bucket_aggregator_spec do
    opts =
      :distcount
      |> Application.get_env(Distcount.Counters.TimeBucketAggregator, [])
      |> Keyword.put_new(:name, Distcount.Counters)

    {Distcount.Counters.TimeBucketAggregator, opts}
  end
end
