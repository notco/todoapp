defmodule Todoapp.TodosTest do
  use Todoapp.DataCase

  alias Todoapp.Todos

  describe "tasks" do
    alias Todoapp.Todos.Task

    import Todoapp.TodosFixtures

    @invalid_attrs %{position: nil, status: nil, description: nil, title: nil}

    test "list_tasks/0 returns all tasks" do
      task = task_fixture()
      assert Todos.list_tasks() == [task]
    end

    test "get_task!/1 returns the task with given id" do
      task = task_fixture()
      assert Todos.get_task!(task.id) == task
    end

    test "create_task/1 with valid data creates a task" do
      valid_attrs = %{position: "some position", status: :pending, description: "some description", title: "some title"}

      assert {:ok, %Task{} = task} = Todos.create_task(valid_attrs)
      assert task.position == "some position"
      assert task.status == :pending
      assert task.description == "some description"
      assert task.title == "some title"
    end

    test "create_task/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Todos.create_task(@invalid_attrs)
    end

    test "update_task/2 with valid data updates the task" do
      task = task_fixture()
      update_attrs = %{position: "some updated position", status: :in_progress, description: "some updated description", title: "some updated title"}

      assert {:ok, %Task{} = task} = Todos.update_task(task, update_attrs)
      assert task.position == "some updated position"
      assert task.status == :in_progress
      assert task.description == "some updated description"
      assert task.title == "some updated title"
    end

    test "update_task/2 with invalid data returns error changeset" do
      task = task_fixture()
      assert {:error, %Ecto.Changeset{}} = Todos.update_task(task, @invalid_attrs)
      assert task == Todos.get_task!(task.id)
    end

    test "delete_task/1 deletes the task" do
      task = task_fixture()
      assert {:ok, %Task{}} = Todos.delete_task(task)
      assert_raise Ecto.NoResultsError, fn -> Todos.get_task!(task.id) end
    end

    test "change_task/1 returns a task changeset" do
      task = task_fixture()
      assert %Ecto.Changeset{} = Todos.change_task(task)
    end
  end
end
