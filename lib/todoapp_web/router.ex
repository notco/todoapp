defmodule TodoappWeb.Router do
  use TodoappWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TodoappWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TodoappWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/tasks", TaskLive.Index, :index
    live "/tasks/new", TaskLive.Form, :new
    live "/tasks/:id", TaskLive.Show, :show
    live "/tasks/:id/edit", TaskLive.Form, :edit
  end

  # Other scopes may use custom stacks.
  scope "/api", TodoappWeb do
    pipe_through :api

    # Must come before `resources` so "paginated" isn't matched as :id.
    get "/tasks/paginated", TaskController, :paginated

    resources "/tasks", TaskController, except: [:new, :edit]
    post "/tasks/:id/reorder", TaskController, :reorder
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:todoapp, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TodoappWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
