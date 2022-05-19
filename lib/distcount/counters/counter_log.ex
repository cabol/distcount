defmodule Distcount.Counters.CounterLog do
  @moduledoc """
  CounterLog schema.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @typedoc "Counter's type"
  @type t :: %__MODULE__{
          key: binary | nil,
          value: integer | nil
        }

  schema "counters_log" do
    field :key, :string
    field :value, :integer

    timestamps()
  end

  @doc false
  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(t, attrs) do
    t
    |> cast(attrs, [:key, :value])
    |> validate_required([:key, :value])
  end

  @doc false
  @spec validate(map) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def validate(attrs) do
    changeset = changeset(%__MODULE__{}, attrs)

    if changeset.valid? do
      {:ok, apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end
end
