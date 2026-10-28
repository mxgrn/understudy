defmodule Understudy.Translator.ReqLLMTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Understudy.Message
  alias Understudy.Translator

  @opts [
    model: "openai:gpt-4o-mini",
    persona: "You translate the UI of Lexicorn, a Telegram bot for learning vocabulary.",
    style: "Informal and friendly.",
    glossary: %{"streak" => "the number of days in a row with at least one review"},
    rules: [~s(Never translate "Lexicorn".)],
    contexts: %{"button" => "This is the text of a button. Use the infinitive form of verbs."}
  ]

  test "translates a singular message with the configured instructions" do
    message = %Message{
      text: "Keep your %{days}-day streak!",
      locale: "es",
      source_locale: "en",
      domain: "default",
      context: "button",
      placeholders: [:days]
    }

    expect(ReqLLM, :generate_object, fn "openai:gpt-4o-mini", prompt, schema, [] ->
      assert prompt =~ "You translate the UI of Lexicorn"
      assert prompt =~ "Informal and friendly."
      assert prompt =~ "streak: the number of days in a row with at least one review"
      assert prompt =~ ~s(Never translate "Lexicorn".)
      assert prompt =~ "This is the text of a button."
      assert prompt =~ "%{days}"
      assert prompt =~ ~s(from "en" to "es")
      assert prompt =~ "<text>\nKeep your %{days}-day streak!\n</text>"
      assert Keyword.has_key?(schema, :translation)

      {:ok, response(%{"translation" => "¡Mantén tu racha de %{days} días!"})}
    end)

    assert Translator.ReqLLM.translate(message, @opts) ==
             {:ok, "¡Mantén tu racha de %{days} días!"}
  end

  test "asks for one translation for each plural form" do
    message = %Message{
      text: "%{count} card",
      plural_text: "%{count} cards",
      locale: "ru",
      source_locale: "en",
      domain: "default",
      placeholders: [:count],
      plural_examples: [[1, 21, 31], [2, 3, 4], [0, 5, 6]]
    }

    expect(ReqLLM, :generate_object, fn _model, prompt, schema, [] ->
      assert prompt =~ "1. Counts such as 1, 21, 31"
      assert prompt =~ "3. Counts such as 0, 5, 6"
      assert prompt =~ "<singular>\n%{count} card\n</singular>"
      assert prompt =~ "<plural>\n%{count} cards\n</plural>"
      assert Keyword.has_key?(schema, :forms)

      {:ok,
       response(%{"forms" => ["%{count} карточка", "%{count} карточки", "%{count} карточек"]})}
    end)

    assert Translator.ReqLLM.translate(message, model: "openai:gpt-4o-mini") ==
             {:ok, ["%{count} карточка", "%{count} карточки", "%{count} карточек"]}
  end

  defp response(object) do
    %ReqLLM.Response{id: "resp_8f2c1a", model: "gpt-4o-mini", context: nil, object: object}
  end
end
