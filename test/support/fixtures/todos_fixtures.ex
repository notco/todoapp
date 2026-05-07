defmodule Todoapp.TodosFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Todoapp.Todos` context.
  """

  @doc """
  Generate a task.
  """
  def task_fixture(attrs \\ %{}) do
    {:ok, task} =
      attrs
      |> Enum.into(%{
        description: "some description",
        position: "some position",
        status: :pending,
        title: "some title"
      })
      |> Todoapp.Todos.create_task()

    task
  end
end
