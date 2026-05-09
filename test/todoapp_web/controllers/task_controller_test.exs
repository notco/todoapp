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

    test "auto-assigns strictly increasing positions when none is provided",
         %{conn: conn} do
      titles =
        for n <- 1..3 do
          title = "#{n}"

          conn
          |> post(~p"/api/tasks",
            task: %{title: title, description: "d", status: "pending"}
          )
          |> json_response(201)

          title
        end

      positions_in_create_order =
        conn
        |> get(~p"/api/tasks")
        |> json_response(200)
        |> Map.fetch!("data")
        |> Enum.sort_by(& &1["title"])
        |> Enum.map(& &1["position"])

      assert length(positions_in_create_order) == length(titles),
             "expected all created tasks in the list response"

      Enum.each(positions_in_create_order, fn p ->
        assert is_binary(p) and p != "",
               "expected a non-empty derived position, got #{inspect(p)}"

        refute String.ends_with?(p, "0"),
               "derived position #{inspect(p)} ends in min char"
      end)

      [p1, p2, p3] = positions_in_create_order

      assert p1 < p2 and p2 < p3,
             "expected strictly increasing positions, got #{inspect(positions_in_create_order)}"
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

  describe "paginated listing" do
    test "no params returns the first page with a next_cursor when more rows exist",
         %{conn: conn} do
      # Default page size is 50; create 60 tasks so a follow-up page exists.
      for n <- 1..60 do
        post(conn, ~p"/api/tasks",
          task: %{
            title: "p#{String.pad_leading("#{n}", 3, "0")}",
            description: "d",
            status: "pending"
          }
        )
      end

      resp =
        conn
        |> get(~p"/api/tasks/paginated")
        |> json_response(200)

      assert length(resp["data"]) == 50, "expected default page size of 50"
      assert is_binary(resp["next_cursor"]), "expected a non-nil cursor when more pages exist"

      # Cursor should match the last item's position so the client can continue.
      assert resp["next_cursor"] == List.last(resp["data"])["position"]
    end

    test "next_cursor is null when fewer rows than the limit are returned",
         %{conn: conn} do
      for n <- 1..3 do
        post(conn, ~p"/api/tasks",
          task: %{title: "p#{n}", description: "d", status: "pending"}
        )
      end

      resp =
        conn
        |> get(~p"/api/tasks/paginated?limit=10")
        |> json_response(200)

      assert length(resp["data"]) == 3
      assert resp["next_cursor"] == nil
    end

    test "explicit limit is respected", %{conn: conn} do
      for n <- 1..5 do
        post(conn, ~p"/api/tasks",
          task: %{title: "p#{n}", description: "d", status: "pending"}
        )
      end

      resp =
        conn
        |> get(~p"/api/tasks/paginated?limit=2")
        |> json_response(200)

      assert length(resp["data"]) == 2
      assert is_binary(resp["next_cursor"])
    end

    test "following the cursor walks every row exactly once without duplicates",
         %{conn: conn} do
      created_titles =
        for n <- 1..25 do
          title = "p#{String.pad_leading("#{n}", 3, "0")}"

          post(conn, ~p"/api/tasks",
            task: %{title: title, description: "d", status: "pending"}
          )

          title
        end

      collected = collect_pages(conn, "/api/tasks/paginated?limit=7", [])

      titles =
        collected
        |> Enum.map(& &1["title"])
        |> Enum.filter(&(&1 in created_titles))

      assert length(titles) == 25, "expected to see every created task exactly once"
      assert Enum.uniq(titles) == titles, "saw a duplicate while paging"

      positions = Enum.map(collected, & &1["position"])

      assert positions == Enum.sort(positions, :desc),
             "pages were not returned in descending position order"
    end

    test "garbage limit falls back to default rather than 500-ing", %{conn: conn} do
      resp =
        conn
        |> get(~p"/api/tasks/paginated?limit=not-a-number")
        |> json_response(200)

      assert is_list(resp["data"])
      assert Map.has_key?(resp, "next_cursor")
    end

    test "empty table returns an empty page with a null cursor", %{conn: conn} do
      resp =
        conn
        |> get(~p"/api/tasks/paginated")
        |> json_response(200)

      assert resp["data"] == []
      assert resp["next_cursor"] == nil
    end
  end

  defp collect_pages(conn, path, acc) do
    resp =
      conn
      |> get(path)
      |> json_response(200)

    acc = acc ++ resp["data"]

    case resp["next_cursor"] do
      nil ->
        acc

      next ->
        # Strip any prior `after=...` so each request carries only the
        # latest cursor, then re-append using the right separator.
        base = String.replace(path, ~r/[?&]after=[^&]*/, "")
        sep = if String.contains?(base, "?"), do: "&", else: "?"
        next_path = "#{base}#{sep}after=#{URI.encode_www_form(next)}"
        collect_pages(conn, next_path, acc)
    end
  end

  defp create_task(_) do
    task = task_fixture()

    %{task: task}
  end
end
