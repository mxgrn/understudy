defmodule Understudy do
  @moduledoc """
  Understudy translates missing Gettext messages at runtime with an LLM and
  caches the result in the database and in memory.

  See `Understudy.Backend` for the setup and `Understudy.Translator` to write
  your own translator.
  """

  alias Understudy.Translations

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

  @doc """
  Translates and caches the messages in the `.pot` templates of the backend that
  the `.po` files of `locale` do not have. Run it after a deploy to fill the cache
  before users ask for the messages.

  Returns `:ok`, or `{:error, failed}` with a `{domain, context, msgid}` tuple for
  each message that the translator could not translate.

  ## Options

    * `:domains` - the domains to prewarm. Defaults to all `.pot` files.
    * `:max_concurrency` - the number of messages to translate at the same time.
      Defaults to `5`.
    * `:skip_translated` - skip the messages that the `.po` files of `locale` have.
      Defaults to `true`. With `false`, it translates and caches all messages. The
      `.po` translations still win at runtime.
  """
  def prewarm(backend, locale, opts \\ []) do
    opts = Keyword.validate!(opts, [:domains, max_concurrency: 5, skip_translated: true])

    if Translations.source_locale?(backend, locale) do
      raise ArgumentError, "#{inspect(locale)} is the source locale of #{inspect(backend)}"
    end

    failed =
      backend
      |> template_messages(opts[:domains])
      |> Task.async_stream(&prewarm_message(backend, locale, opts[:skip_translated], &1),
        max_concurrency: opts[:max_concurrency],
        ordered: false,
        timeout: :infinity
      )
      |> Enum.flat_map(fn
        {:ok, :ok} -> []
        {:ok, {:error, key}} -> [key]
      end)

    if failed == [], do: :ok, else: {:error, failed}
  end

  defp template_messages(backend, domains) do
    priv = backend.__gettext__(:priv)

    # In a release, the priv dir is inside the app dir, not in the current directory.
    dir =
      if Path.type(priv) == :absolute,
        do: priv,
        else: Application.app_dir(backend.__gettext__(:otp_app), priv)

    for path <- Path.wildcard(Path.join(dir, "*.pot")),
        domain = Path.basename(path, ".pot"),
        is_nil(domains) or domain in domains,
        message <- Expo.PO.parse_file!(path).messages,
        do: {domain, message}
  end

  # Through lgettext/lngettext, the backend falls back to the translator only for messages that
  # the .po files do not have. Each placeholder gets an empty binding, so that the result is not
  # a missing-bindings error.
  defp prewarm_message(backend, locale, skip_translated, {domain, message}) do
    {context, text} = Expo.Message.key(message)
    context = if context == "", do: nil, else: context

    plural_text =
      case message do
        %Expo.Message.Plural{msgid_plural: plural_text} -> IO.iodata_to_binary(plural_text)
        %Expo.Message.Singular{} -> nil
      end

    result =
      case {skip_translated, plural_text} do
        {true, nil} ->
          backend.lgettext(locale, domain, context, text, empty_bindings(text))

        {true, plural_text} ->
          bindings = empty_bindings(text <> plural_text)
          backend.lngettext(locale, domain, context, text, plural_text, 1, bindings)

        {false, nil} ->
          Translations.translate(backend, locale, domain, context, text)

        {false, plural_text} ->
          Translations.translate_plural(backend, locale, domain, context, text, plural_text, 1)
      end

    case result do
      {:ok, _translation} -> :ok
      _default_or_error -> {:error, {domain, context, text}}
    end
  end

  defp empty_bindings(text) do
    text |> Gettext.Interpolation.Default.keys() |> Map.new(&{&1, ""})
  end
end
