defmodule Understudy.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [Understudy.MemoryCache]
    Supervisor.start_link(children, strategy: :one_for_one, name: Understudy.Supervisor)
  end
end
