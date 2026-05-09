defmodule TodoappWeb.TaskJSON do
  alias Todoapp.Todos.Task

  @doc """
  Renders a list of tasks. Note that the default limit
  for results is 50 items.
  """
  def index(%{tasks: tasks}) do
    %{data: for(task <- tasks, do: data(task))}
  end

  @doc """
  Renders a paginated page of tasks plus the cursor for the next page.

  `next_cursor` is `nil` when the client has reached the end of the
  table; otherwise it's the `position` to pass back as `?after=`.
  """
  def paginated(%{tasks: tasks, next_cursor: next_cursor}) do
    %{
      data: for(task <- tasks, do: data(task)),
      next_cursor: next_cursor
    }
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
