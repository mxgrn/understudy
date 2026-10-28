defmodule Understudy.Translation do
  @moduledoc """
  A cached translation. You can delete rows safely: the next request for the
  message translates it again, but it is slower.
  """
  use Ecto.Schema

  schema "understudy_translations" do
    field(:locale, :string)
    field(:domain, :string)
    field(:context, :string, default: "")
    field(:text, :string)
    field(:plural_text, :string)
    # sha256 of the text and the plural text, so that the unique index stays small
    field(:text_hash, :binary)
    field(:plural_index, :integer, default: 0)
    field(:value, :string)

    timestamps()
  end
end
