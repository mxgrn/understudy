defmodule Understudy.Backend do
  @moduledoc """
  A Gettext backend that translates missing messages with a `Understudy.Translator`
  and caches the result.

      defmodule MyApp.Gettext do
        use Understudy.Backend,
          otp_app: :my_app,
          repo: MyApp.Repo,
          translator: {Understudy.Translator.ReqLLM, model: "openai:gpt-4o-mini"}
      end

  Messages in `.po` files win. Only missing messages go to the translator.

  ## Options

    * `:repo` (required) - the Ecto repo that has the `understudy_translations` table
    * `:translator` (required) - a module that implements `Understudy.Translator`,
      or a `{module, opts}` tuple
    * `:source_locale` - the locale of the msgids. Defaults to `"en"`. The backend
      does not translate messages in this locale or its variants (`"en-GB"`, `"en_US"`).
    * `:memory_cache` - keep translations in ETS. Defaults to `true`. Set it to
      `false` in the test environment if your tests use the SQL sandbox.

  All other options go to `Gettext.Backend`.
  """

  @understudy_keys [:repo, :translator, :source_locale, :memory_cache]

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts, understudy_keys: @understudy_keys] do
      {understudy_opts, gettext_opts} = Keyword.split(opts, understudy_keys)

      use Gettext.Backend, gettext_opts

      @understudy_config Understudy.Backend.config!(understudy_opts, gettext_opts)

      @doc false
      def __understudy__(:config), do: @understudy_config

      def handle_missing_translation(locale, domain, msgctxt, msgid, bindings) do
        case Understudy.Translations.translate(__MODULE__, locale, domain, msgctxt, msgid) do
          {:ok, translation} ->
            __gettext__(:interpolation).runtime_interpolate(translation, bindings)

          :error ->
            super(locale, domain, msgctxt, msgid, bindings)
        end
      end

      def handle_missing_plural_translation(
            locale,
            domain,
            msgctxt,
            msgid,
            msgid_plural,
            n,
            bindings
          ) do
        case Understudy.Translations.translate_plural(
               __MODULE__,
               locale,
               domain,
               msgctxt,
               msgid,
               msgid_plural,
               n
             ) do
          {:ok, translation} ->
            __gettext__(:interpolation).runtime_interpolate(
              translation,
              Map.put(bindings, :count, n)
            )

          :error ->
            super(locale, domain, msgctxt, msgid, msgid_plural, n, bindings)
        end
      end
    end
  end

  @doc false
  def config!(understudy_opts, gettext_opts) do
    understudy_opts =
      Keyword.validate!(understudy_opts, [
        :repo,
        :translator,
        source_locale: "en",
        memory_cache: true
      ])

    {translator, translator_opts} =
      case Keyword.fetch!(understudy_opts, :translator) do
        {module, opts} -> {module, opts}
        module -> {module, []}
      end

    %{
      repo: Keyword.fetch!(understudy_opts, :repo),
      translator: translator,
      translator_opts: translator_opts,
      source_locale: understudy_opts[:source_locale],
      memory_cache: understudy_opts[:memory_cache],
      plural_forms:
        gettext_opts[:plural_forms] ||
          Application.get_env(:gettext, :plural_forms, Gettext.Plural)
    }
  end
end
