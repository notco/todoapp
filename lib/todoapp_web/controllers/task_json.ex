defmodule TodoappWeb.TaskJSON do
  alias Todoapp.Todos.Task

  @doc """
  Renders a list of tasks.
  """
  def index(%{tasks: tasks}) do
    %{data: for(task <- tasks, do: data(task))}
  end

  @doc """
  Renders a single task.
  """
  def show(%{task: task}) do
    %{data: data(task)}
  end

  defp data(%Task{} = task) do
    %{
      id: task.id,
      title: task.title,
      description: task.description,
      status: task.status,
      position: task.position
    }
  end
end
