defmodule Understudy do
  @moduledoc """
  Understudy translates missing Gettext messages at runtime with an LLM and
  caches the result in the database and in memory.

  See `Understudy.Backend` for the setup and `Understudy.Translator` to write
  your own translator.
  """

  @doc """
  Translates text that is not known at compile time, for example text built
  from data.

  The text goes through the backend like a `dpgettext` call, so a translation
  in a `.po` file wins.

  ## Options

    * `:locale` - the target locale. Defaults to the current locale of the backend.
    * `:domain` - the Gettext domain. Defaults to `"default"`.
    * `:context` - the Gettext context (msgctxt). Defaults to `nil`.
    * `:bindings` - the interpolation bindings. Defaults to `%{}`.
  """
  def translate(backend, text, opts \\ []) do
    opts = Keyword.validate!(opts, [:locale, :context, domain: "default", bindings: %{}])

    translate = fn ->
      Gettext.dpgettext(backend, opts[:domain], opts[:context], text, opts[:bindings])
    end

    case opts[:locale] do
      nil -> translate.()
      locale -> Gettext.with_locale(backend, locale, translate)
    end
  end
end
