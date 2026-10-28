defmodule Understudy.Translator do
  @moduledoc """
  Behaviour for modules that translate a message, usually with an LLM.

  For a singular message, return `{:ok, translation}`. For a plural message
  (`message.plural_text` is not `nil`), return `{:ok, forms}`, a list with one
  translation for each plural form of the locale, in the order of
  `message.plural_examples`.
  """

  @callback translate(Understudy.Message.t(), opts :: keyword()) ::
              {:ok, String.t() | [String.t()]} | {:error, term()}
end
