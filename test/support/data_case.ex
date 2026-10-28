defmodule Understudy.DataCase do
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      use Mimic

      alias Understudy.Message
      alias Understudy.TestRepo
      alias Understudy.TestTranslator
      alias Understudy.Translation
    end
  end

  setup do
    pid = Sandbox.start_owner!(Understudy.TestRepo)
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    Understudy.MemoryCache.clear()
    :ok
  end
end
