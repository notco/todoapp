defmodule TodoappWeb.TaskLiveTest do
  use TodoappWeb.ConnCase

  import Phoenix.LiveViewTest
  import Todoapp.TodosFixtures

  @create_attrs %{position: "some position", status: :pending, description: "some description", title: "some title"}
  @update_attrs %{position: "some updated position", status: :in_progress, description: "some updated description", title: "some updated title"}
  @invalid_attrs %{position: nil, status: nil, description: nil, title: nil}
  defp create_task(_) do
    task = task_fixture()

    %{task: task}
  end

  describe "Index" do
    setup [:create_task]

    test "lists all tasks", %{conn: conn, task: task} do
      {:ok, _index_live, html} = live(conn, ~p"/tasks")

      assert html =~ "Listing Tasks"
      assert html =~ task.title
    end

    test "saves new task", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/tasks")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Task")
               |> render_click()
               |> follow_redirect(conn, ~p"/tasks/new")

      assert render(form_live) =~ "New Task"

      assert form_live
             |> form("#task-form", task: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#task-form", task: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/tasks")

      html = render(index_live)
      assert html =~ "Task created successfully"
      assert html =~ "some title"
    end

    test "updates task in listing", %{conn: conn, task: task} do
      {:ok, index_live, _html} = live(conn, ~p"/tasks")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#tasks-#{task.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/tasks/#{task}/edit")

      assert render(form_live) =~ "Edit Task"

      assert form_live
             |> form("#task-form", task: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#task-form", task: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/tasks")

      html = render(index_live)
      assert html =~ "Task updated successfully"
      assert html =~ "some updated title"
    end

    test "deletes task in listing", %{conn: conn, task: task} do
      {:ok, index_live, _html} = live(conn, ~p"/tasks")

      assert index_live |> element("#tasks-#{task.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#tasks-#{task.id}")
    end
  end

  describe "Show" do
    setup [:create_task]

    test "displays task", %{conn: conn, task: task} do
      {:ok, _show_live, html} = live(conn, ~p"/tasks/#{task}")

      assert html =~ "Show Task"
      assert html =~ task.title
    end

    test "updates task and returns to show", %{conn: conn, task: task} do
      {:ok, show_live, _html} = live(conn, ~p"/tasks/#{task}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/tasks/#{task}/edit?return_to=show")

      assert render(form_live) =~ "Edit Task"

      assert form_live
             |> form("#task-form", task: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#task-form", task: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/tasks/#{task}")

      html = render(show_live)
      assert html =~ "Task updated successfully"
      assert html =~ "some updated title"
    end
  end
end
