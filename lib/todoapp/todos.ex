defmodule Todoapp.Todos do
  @moduledoc """
  The Todos context.
  """

  import Ecto.Query, warn: false
  alias Todoapp.Repo

  alias Todoapp.Todos.Task

  @doc """
  Returns the list of tasks.

  ## Examples

      iex> list_tasks()
      [%Task{}, ...]

  """
  def list_tasks do
    Task
    |> order_by(desc: :position)
    |> Repo.all()
  end

  @doc """
  Gets a single task.

  Raises `Ecto.NoResultsError` if the Task does not exist.

  ## Examples

      iex> get_task!(123)
      %Task{}

      iex> get_task!(456)
      ** (Ecto.NoResultsError)

  """
  def get_task!(id), do: Repo.get!(Task, id)

  @doc """
  Creates a task.

  ## Examples

      iex> create_task(%{field: value})
      {:ok, %Task{}}

      iex> create_task(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_task(attrs) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a task.

  ## Examples

      iex> update_task(task, %{field: new_value})
      {:ok, %Task{}}

      iex> update_task(task, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_task(%Task{} = task, attrs) do
    task
    |> Task.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a task.

  ## Examples

      iex> delete_task(task)
      {:ok, %Task{}}

      iex> delete_task(task)
      {:error, %Ecto.Changeset{}}

  """
  def delete_task(%Task{} = task) do
    Repo.delete(task)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking task changes.

  ## Examples

      iex> change_task(task)
      %Ecto.Changeset{data: %Task{}}

  """
  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end

  def max_position do
    Repo.one(from t in Task, select: max(t.position))
  end

  @doc """
  Returns a paginated page of tasks ordered by position (descending).
  Pagination is cursor-based on `:position`

  ## Options
    * `:limit` — page size. Defaults to `50`. (TODO: clamp to a sane
      maximum once we decide on the cap; today an enormous `:limit`
      will happily return the whole table.)
    * `:after` — cursor returned from a previous call. When `nil` (or
      absent), the call returns the first page.

  ## Returns
  `{tasks, next_cursor}` — when `next_cursor` is `nil`, the caller has
  reached the end of the table. Otherwise pass it back as `:after` to
  fetch the next page.

  ## Examples

      iex> {tasks, next} = paginate_tasks(limit: 100)
      iex> {more, nil} = paginate_tasks(limit: 100, after: next)
  """
  def paginate_tasks(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    cursor = Keyword.get(opts, :after)

    # Fetch one extra row so we can tell whether another page exists
    # without firing a separate COUNT query.
    rows =
      Task
      |> apply_cursor(cursor)
      |> order_by(desc: :position)
      |> limit(^(limit + 1))
      |> Repo.all()

    if length(rows) > limit do
      page = Enum.take(rows, limit)
      {page, List.last(page).position}
    else
      {rows, nil}
    end
  end

  defp apply_cursor(query, cursor) when is_binary(cursor) and cursor != "" do
    # Descending order, so "after this cursor" means "smaller than it".
    where(query, [t], t.position < ^cursor)
  end

  defp apply_cursor(query, _), do: query
end
