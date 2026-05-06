defmodule TodoappWeb.PageController do
  use TodoappWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
