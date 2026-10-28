if Code.ensure_loaded?(ReqLLM) do
  defmodule Understudy.Translator.ReqLLM do
    @moduledoc """
    The default translator. It asks an LLM through `ReqLLM` for a structured response.

        use Understudy.Backend,
          otp_app: :my_app,
          repo: MyApp.Repo,
          translator:
            {Understudy.Translator.ReqLLM,
             model: "openai:gpt-4o-mini",
             persona: "You translate the UI of MyApp, a tool for learning vocabulary.",
             style: "Informal and friendly.",
             glossary: %{"streak" => "the number of days in a row with at least one review"},
             rules: [~s(Never translate "MyApp".)],
             contexts: %{"button" => "This is the text of a button."}}

    ## Options

      * `:model` (required) - a ReqLLM model spec
      * `:persona` - who the translator is and what it translates
      * `:style` - the tone of the translations
      * `:glossary` - a map of terms to their meaning in your app
      * `:rules` - a list of extra rules
      * `:contexts` - a map of Gettext contexts (msgctxt) to extra instructions
      * `:llm_opts` - options for `ReqLLM.generate_object/4`, for example `[temperature: 0.5]`
    """
    @behaviour Understudy.Translator

    alias Understudy.Message

    @default_persona "You translate the user interface of an app."

    @impl true
    def translate(%Message{} = message, opts) do
      opts =
        Keyword.validate!(opts, [
          :model,
          :style,
          persona: @default_persona,
          glossary: %{},
          rules: [],
          contexts: %{},
          llm_opts: []
        ])

      {schema, field} = schema(message)

      case ReqLLM.generate_object(opts[:model], prompt(message, opts), schema, opts[:llm_opts]) do
        {:ok, %{object: %{^field => result}}} -> {:ok, result}
        {:ok, response} -> {:error, {:invalid_response, response}}
        {:error, reason} -> {:error, reason}
      end
    end

    defp schema(%Message{plural_text: nil}) do
      {[translation: [type: :string, required: true]], "translation"}
    end

    defp schema(_message) do
      {[forms: [type: {:list, :string}, required: true]], "forms"}
    end

    defp prompt(message, opts) do
      [
        opts[:persona],
        opts[:style] && "Style: #{opts[:style]}",
        glossary(opts[:glossary]),
        rules(message, opts[:rules]),
        Map.get(opts[:contexts], message.context),
        task(message)
      ]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join("\n\n")
    end

    defp glossary(glossary) when glossary == %{}, do: nil

    defp glossary(glossary) do
      "Glossary:\n" <>
        Enum.map_join(glossary, "\n", fn {term, meaning} -> "- #{term}: #{meaning}" end)
    end

    defp rules(message, rules) do
      placeholder_rule =
        if message.placeholders != [] do
          "Keep these placeholders unchanged: " <>
            Enum.map_join(message.placeholders, ", ", &"%{#{&1}}") <> "."
        end

      rules = [
        placeholder_rule,
        "Keep the formatting and the empty lines of the source text.",
        "Do not add explanations." | rules
      ]

      "Rules:\n" <> (rules |> Enum.reject(&is_nil/1) |> Enum.map_join("\n", &"- #{&1}"))
    end

    defp task(%Message{plural_text: nil} = message) do
      """
      Translate the text below from "#{message.source_locale}" to "#{message.locale}".

      <text>
      #{message.text}
      </text>\
      """
    end

    defp task(message) do
      forms =
        message.plural_examples
        |> Enum.with_index(1)
        |> Enum.map_join("\n", fn
          {[], index} -> "#{index}. Other counts"
          {counts, index} -> "#{index}. Counts such as #{Enum.join(counts, ", ")}"
        end)

      """
      Translate the text below from "#{message.source_locale}" to "#{message.locale}". \
      It has a singular and a plural form. In "#{message.locale}", give one translation \
      for each of these forms, in this order:
      #{forms}

      <singular>
      #{message.text}
      </singular>

      <plural>
      #{message.plural_text}
      </plural>\
      """
    end
  end
end
