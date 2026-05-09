defmodule TodoappWeb.TaskController do
  use TodoappWeb, :controller

  alias Todoapp.Todos
  alias Todoapp.Todos.Task
  alias Todoapp.Helpers.FractionalIndex

  action_fallback TodoappWeb.FallbackController

  def index(conn, _params) do
    tasks = Todos.list_tasks()
    render(conn, :index, tasks: tasks)
  end

  def paginated(conn, params) do
    opts =
      []
      |> maybe_put(:limit, parse_limit(params["limit"]))
      |> maybe_put(:after, params["after"])

    {tasks, next_cursor} = Todos.paginate_tasks(opts)

    render(conn, :paginated, tasks: tasks, next_cursor: next_cursor)
  end

  def create(conn, %{"task" => task_params}) do
    task_params =
      maybe_assign_position(task_params)

    with {:ok, %Task{} = task} <- Todos.create_task(task_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/tasks/#{task}")
      |> render(:show, task: task)
    end
  end

  def show(conn, %{"id" => id}) do
    task = Todos.get_task!(id)
    render(conn, :show, task: task)
  end

  def update(conn, %{"id" => id, "task" => task_params}) do
    task = Todos.get_task!(id)

    with {:ok, %Task{} = task} <- Todos.update_task(task, task_params) do
      render(conn, :show, task: task)
    end
  end

  def delete(conn, %{"id" => id}) do
    task = Todos.get_task!(id)

    with {:ok, %Task{}} <- Todos.delete_task(task) do
      send_resp(conn, :no_content, "")
    end
  end

  def reorder(conn, %{"id" => id} = params) do
    task = Todos.get_task!(id)
    prev_pos = params["prev_pos"]
    next_pos = params["next_pos"]

    case FractionalIndex.generate_position(prev_pos, next_pos) do
      {:ok, new_pos} ->
        task_params = %{"position" => new_pos}

        with {:ok, %Task{} = task} <- Todos.update_task(task, task_params) do
          render(conn, :show, task: task)
        end

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason, message: "Failed to reorder task"})
    end
  end

  defp maybe_assign_position(%{"position" => pos} = params)
       when is_binary(pos) and pos != "",
       do: params

  defp maybe_assign_position(params) do
    case FractionalIndex.generate_position(
           Todos.max_position(),
           nil
         ) do
      {:ok, new_pos} -> Map.put(params, "position", new_pos)
      {:error, _} -> params
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: [{key, value} | opts]

  defp parse_limit(nil), do: nil

  defp parse_limit(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} when n > 0 -> n
      _ -> nil
    end
  end
end
