defmodule TodoappWeb.TaskLive.Form do
  use TodoappWeb, :live_view

  alias Todoapp.Todos
  alias Todoapp.Todos.Task

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage task records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="task-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:title]} type="text" label="Title" />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input
          field={@form[:status]}
          type="select"
          label="Status"
          prompt="Choose a value"
          options={Ecto.Enum.values(Todoapp.Todos.Task, :status)}
        />
        <.input field={@form[:position]} type="textarea" label="Position" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Task</.button>
          <.button navigate={return_path(@return_to, @task)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    task = Todos.get_task!(id)

    socket
    |> assign(:page_title, "Edit Task")
    |> assign(:task, task)
    |> assign(:form, to_form(Todos.change_task(task)))
  end

  defp apply_action(socket, :new, _params) do
    task = %Task{}

    socket
    |> assign(:page_title, "New Task")
    |> assign(:task, task)
    |> assign(:form, to_form(Todos.change_task(task)))
  end

  @impl true
  def handle_event("validate", %{"task" => task_params}, socket) do
    changeset = Todos.change_task(socket.assigns.task, task_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"task" => task_params}, socket) do
    save_task(socket, socket.assigns.live_action, task_params)
  end

  defp save_task(socket, :edit, task_params) do
    case Todos.update_task(socket.assigns.task, task_params) do
      {:ok, task} ->
        {:noreply,
         socket
         |> put_flash(:info, "Task updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, task))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_task(socket, :new, task_params) do
    case Todos.create_task(task_params) do
      {:ok, task} ->
        {:noreply,
         socket
         |> put_flash(:info, "Task created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, task))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _task), do: ~p"/tasks"
  defp return_path("show", task), do: ~p"/tasks/#{task}"
end
