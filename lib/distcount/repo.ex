defmodule Distcount.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :distcount,
    adapter: Ecto.Adapters.Postgres
end
