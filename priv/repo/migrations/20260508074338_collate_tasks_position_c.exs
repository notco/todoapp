defmodule Todoapp.Repo.Migrations.CollateTasksPositionC do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      modify :position, :text, collation: "C"
    end
  end
end
