defmodule Understudy.Translations do
  @moduledoc false
  # Finds a translation in the memory cache, then in the database, then asks the translator.

  import Ecto.Query

  alias Understudy.MemoryCache
  alias Understudy.Message
  alias Understudy.Translation

  require Logger

  def translate(backend, locale, domain, context, text) do
    config = backend.__understudy__(:config)

    message = %Message{
      text: text,
      locale: locale,
      source_locale: config.source_locale,
      domain: domain,
      context: context,
      placeholders: placeholders(text)
    }

    if skip?(message) do
      :error
    else
      with {:ok, [translation]} <- fetch(backend, config, message), do: {:ok, translation}
    end
  end

  defp skip?(message) do
    String.trim(message.text) == "" or
      base_language(message.locale) == base_language(message.source_locale)
  end

  defp base_language(locale) do
    locale |> String.split(["-", "_"]) |> hd() |> String.downcase()
  end

  defp placeholders(text) do
    text |> Gettext.Interpolation.Default.keys() |> Enum.uniq()
  end

  defp fetch(backend, config, message) do
    key =
      {backend, message.locale, message.domain, message.context, message.text,
       message.plural_text}

    with :miss <- from_memory(config, key),
         :miss <- from_database(config, message),
         :miss <- from_translator(config, message) do
      :error
    else
      {:ok, forms} = found ->
        if config.memory_cache, do: MemoryCache.put(key, forms)
        found
    end
  end

  defp from_memory(%{memory_cache: false}, _key), do: :miss

  defp from_memory(_config, key) do
    case MemoryCache.get(key) do
      nil -> :miss
      forms -> {:ok, forms}
    end
  end

  defp from_database(config, message) do
    forms =
      from(t in Translation,
        where:
          t.locale == ^message.locale and t.domain == ^message.domain and
            t.context == ^(message.context || "") and t.text_hash == ^text_hash(message),
        order_by: t.plural_index,
        select: t.value
      )
      |> config.repo.all()

    if forms != [] and length(forms) == form_count(message), do: {:ok, forms}, else: :miss
  end

  defp from_translator(config, message) do
    with {:ok, result} <- config.translator.translate(message, config.translator_opts),
         forms = List.wrap(result),
         :ok <- validate(message, forms) do
      insert!(config, message, forms)
      {:ok, forms}
    else
      error ->
        Logger.warning(
          "Understudy could not translate #{inspect(message.text)} to #{message.locale}: #{inspect(error)}"
        )

        :miss
    end
  end

  defp validate(message, forms) do
    cond do
      length(forms) != form_count(message) ->
        {:error, :wrong_number_of_forms}

      Enum.any?(forms, &(not is_binary(&1) or String.trim(&1) == "")) ->
        {:error, :blank}

      not Enum.all?(forms, &placeholders_match?(message, &1)) ->
        {:error, :placeholders_do_not_match}

      true ->
        :ok
    end
  end

  defp placeholders_match?(message, form) do
    MapSet.new(placeholders(form)) == MapSet.new(message.placeholders)
  end

  defp form_count(%Message{plural_examples: nil}), do: 1
  defp form_count(%Message{plural_examples: examples}), do: length(examples)

  defp insert!(config, message, forms) do
    now = NaiveDateTime.utc_now(:second)

    rows =
      forms
      |> Enum.with_index()
      |> Enum.map(fn {form, index} ->
        %{
          locale: message.locale,
          domain: message.domain,
          context: message.context || "",
          text: message.text,
          plural_text: message.plural_text,
          text_hash: text_hash(message),
          plural_index: index,
          value: form,
          inserted_at: now,
          updated_at: now
        }
      end)

    # another process can translate the same message at the same time
    config.repo.insert_all(Translation, rows, on_conflict: :nothing)
  end

  defp text_hash(message) do
    :crypto.hash(:sha256, [message.text, 0, message.plural_text || ""])
  end
end
