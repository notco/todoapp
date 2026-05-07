defmodule Todoapp.Todos.Task do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tasks" do
    field :title, :string
    field :description, :string
    field :status, Ecto.Enum, values: [:pending, :in_progress, :done]
    field :position, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [:title, :description, :status, :position])
    |> validate_required([:title, :description, :status, :position])
  end
end
