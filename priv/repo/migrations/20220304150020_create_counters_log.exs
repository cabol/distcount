defmodule Distcount.Repo.Migrations.CreateCountersLog do
  use Ecto.Migration

  def change do
    create table(:counters_log) do
      add :key, :string
      add :value, :integer

      timestamps()
    end

    create index(:counters_log, [:key])
  end
end
