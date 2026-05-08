defmodule TodoappWeb.TaskControllerTest do
  use TodoappWeb.ConnCase

  import Todoapp.TodosFixtures
  alias Todoapp.Todos.Task

  @create_attrs %{
    position: "some position",
    status: :pending,
    description: "some description",
    title: "some title"
  }
  @update_attrs %{
    position: "some updated position",
    status: :in_progress,
    description: "some updated description",
    title: "some updated title"
  }
  @invalid_attrs %{position: nil, status: nil, description: nil, title: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all tasks", %{conn: conn} do
      conn = get(conn, ~p"/api/tasks")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create task" do
    test "renders task when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/tasks", task: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/tasks/#{id}")

      assert %{
               "id" => ^id,
               "description" => "some description",
               "position" => "some position",
               "status" => "pending",
               "title" => "some title"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/tasks", task: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update task" do
    setup [:create_task]

    test "renders task when data is valid", %{conn: conn, task: %Task{id: id} = task} do
      conn = put(conn, ~p"/api/tasks/#{task}", task: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/tasks/#{id}")

      assert %{
               "id" => ^id,
               "description" => "some updated description",
               "position" => "some updated position",
               "status" => "in_progress",
               "title" => "some updated title"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, task: task} do
      conn = put(conn, ~p"/api/tasks/#{task}", task: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete task" do
    setup [:create_task]

    test "deletes chosen task", %{conn: conn, task: task} do
      conn = delete(conn, ~p"/api/tasks/#{task}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/tasks/#{task}")
      end
    end
  end

  describe "reorder task" do
    setup [:create_task]

    test "places task between two positions", %{conn: conn, task: task} do
      conn = post(conn, ~p"/api/tasks/#{task}/reorder", prev_pos: "a", next_pos: "c")
      assert %{"position" => "b"} = json_response(conn, 200)["data"]
    end

    test "places task before next position when no prev", %{conn: conn, task: task} do
      conn = post(conn, ~p"/api/tasks/#{task}/reorder", next_pos: "c")
      assert %{"position" => position} = json_response(conn, 200)["data"]
      assert position < "c"
    end

    test "places task after prev position when no next", %{conn: conn, task: task} do
      conn = post(conn, ~p"/api/tasks/#{task}/reorder", prev_pos: "a")
      assert %{"position" => position} = json_response(conn, 200)["data"]
      assert position > "a"
    end

    test "assigns middle position when no positions provided", %{conn: conn, task: task} do
      conn = post(conn, ~p"/api/tasks/#{task}/reorder")
      assert %{"position" => "V"} = json_response(conn, 200)["data"]
    end

    test "returns bad request when positions have no space between them", %{
      conn: conn,
      task: task
    } do
      conn = post(conn, ~p"/api/tasks/#{task}/reorder", prev_pos: "a", next_pos: "a")
      response = json_response(conn, 400)
      assert response["error"] == "no_space"
      assert response["message"] == "Failed to reorder task"
    end

    test "returns no_space when next_pos ends in min char with no room (regression: 'a','a0')",
         %{conn: conn, task: task} do
      conn = post(conn, ~p"/api/tasks/#{task}/reorder", prev_pos: "a", next_pos: "a0")
      response = json_response(conn, 400)
      assert response["error"] == "no_space"
    end

    test "tightly adjacent positions extend rather than collide", %{conn: conn, task: task} do
      conn = post(conn, ~p"/api/tasks/#{task}/reorder", prev_pos: "a", next_pos: "b")
      assert %{"position" => position} = json_response(conn, 200)["data"]
      assert position > "a"
      assert position < "b"
      refute String.ends_with?(position, "0")
    end

    test "supports 100 successive insertions between 'a' and the prior result",
         %{conn: conn, task: _task} do
      # Each iteration creates a *new* task and reorders it strictly
      # between "a" and the position generated on the previous round.
      # After 100 rounds we have 100 inserted tasks (plus whatever the
      # setup created), and the listing endpoint should return ours in
      # sorted position order.
      {inserted_desc, _} =
        Enum.reduce(1..100, {[], "b"}, fn i, {acc, next_pos} ->
          %{"id" => id} =
            conn
            |> post(~p"/api/tasks",
              task: %{
                title: "t#{i}",
                description: "d",
                status: "pending",
                position: "tmp"
              }
            )
            |> json_response(201)
            |> Map.fetch!("data")

          new_pos =
            conn
            |> post(~p"/api/tasks/#{id}/reorder", prev_pos: "a", next_pos: next_pos)
            |> json_response(200)
            |> get_in(["data", "position"])

          assert "a" < new_pos and new_pos < next_pos,
                 "iteration #{i}: #{inspect(new_pos)} not strictly between \"a\" and #{inspect(next_pos)}"

          refute String.ends_with?(new_pos, "0"),
                 "iteration #{i}: #{inspect(new_pos)} ends in min char"

          {[new_pos | acc], new_pos}
        end)

      # Filter the listing to only the positions we generated so the
      # fixture task (with its non-fractional placeholder position)
      # doesn't pollute the comparison.
      ours = MapSet.new(inserted_desc)

      returned =
        conn
        |> get(~p"/api/tasks")
        |> json_response(200)
        |> get_in(["data", Access.all(), "position"])
        |> Enum.filter(&MapSet.member?(ours, &1))

      assert length(returned) == 100,
             "expected 100 inserted positions in the list response, got #{length(returned)}"

      # Direction-agnostic: list_tasks/0 may sort :asc or :desc, but it
      # must be monotonic in one direction. If you've fixed it to one
      # direction, tighten this to a single assertion.
      assert returned == Enum.sort(returned, :asc) or
               returned == Enum.sort(returned, :desc),
             "list endpoint returned positions out of order: #{inspect(returned)}"
    end
  end

  defp create_task(_) do
    task = task_fixture()

    %{task: task}
  end
end
