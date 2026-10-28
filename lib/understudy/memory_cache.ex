defmodule Understudy.MemoryCache do
  @moduledoc """
  An ETS cache in front of the database, so that each render does not query it.

  Entries stay until the application stops. If you change or delete rows in the
  database, call `clear/0`.
  """
  use GenServer

  @table __MODULE__

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def get(key) do
    case :ets.lookup(@table, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  def put(key, value), do: :ets.insert(@table, {key, value})

  def put_all(entries), do: :ets.insert(@table, entries)

  def clear, do: :ets.delete_all_objects(@table)

  @impl true
  def init(nil) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, nil}
  end
end
