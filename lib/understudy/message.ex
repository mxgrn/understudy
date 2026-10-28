defmodule Understudy.Message do
  @moduledoc """
  A message that a `Understudy.Translator` must translate.

    * `:text` - the source text (the msgid)
    * `:plural_text` - the plural source text (the msgid_plural), or `nil`
    * `:locale` - the target locale, for example `"es"` or `"pt_BR"`
    * `:source_locale` - the locale of the source text
    * `:domain` - the Gettext domain
    * `:context` - the Gettext context (msgctxt), or `nil`
    * `:placeholders` - the interpolation keys in the source text, for example `[:name]`
    * `:plural_examples` - for plural messages, one list of sample counts for
      each plural form of the locale, for example `[[1, 21, 31], [2, 3, 4], [0, 5, 6]]`
  """

  @enforce_keys [:text, :locale, :source_locale, :domain]
  defstruct [
    :text,
    :plural_text,
    :locale,
    :source_locale,
    :domain,
    :context,
    placeholders: [],
    plural_examples: nil
  ]

  @type t :: %__MODULE__{}
end
