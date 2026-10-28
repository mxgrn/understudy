# Understudy

Understudy translates missing Gettext messages at runtime with an LLM. It
caches each translation in your database and in ETS, so each message goes to
the LLM only one time for each locale.

Messages in your `.po` files win. Understudy only translates the messages that
are not there.

## Installation

```elixir
def deps do
  [
    {:understudy, github: "mxgrn/understudy"},
    # only if you use the default translator
    {:req_llm, "~> 1.0"}
  ]
end
```

Add the table with a migration:

```elixir
defmodule MyApp.Repo.Migrations.AddUnderstudy do
  use Ecto.Migration

  def up, do: Understudy.Migration.up()
  def down, do: Understudy.Migration.down()
end
```

## Usage

Use `Understudy.Backend` in place of `Gettext.Backend`:

```elixir
defmodule MyApp.Gettext do
  use Understudy.Backend,
    otp_app: :my_app,
    repo: MyApp.Repo,
    translator:
      {Understudy.Translator.ReqLLM,
       model: "openai:gpt-4o-mini",
       persona: "You translate the UI of MyApp, a Telegram bot for learning vocabulary.",
       style: "Informal and friendly.",
       glossary: %{"streak" => "the number of days in a row with at least one review"},
       rules: [~s(Never translate "MyApp".)],
       contexts: %{"button" => "This is the text of a button. Use the infinitive form of verbs."}}
end
```

Then use Gettext as usual:

```elixir
use Gettext, backend: MyApp.Gettext

Gettext.put_locale(MyApp.Gettext, "es")

gettext("Start review")
pgettext("button", "Flip")
ngettext("%{count} card", "%{count} cards", count)
```

For text that is not known at compile time, use `Understudy.translate/3`:

```elixir
Understudy.translate(MyApp.Gettext, "You're done with #{language.name}!", locale: "de")
```

## Prewarming the cache

To translate all messages before users ask for them, for example after a
deploy, run:

```elixir
Understudy.prewarm(MyApp.Gettext, "es")
```

It reads the `.pot` templates of the backend (run `mix gettext.extract` first)
and translates each message that the `.po` files of the locale do not have. It
returns `:ok`, or `{:error, failed}` with the messages that it could not
translate. Use `domains: ["default"]` to prewarm only some domains, and
`max_concurrency:` (default `5`) to set how many messages it translates at the
same time.

Text that you give to `Understudy.translate/3` is not in the templates, so
prewarming does not translate it.

## Backend options

- `:repo` (required): the Ecto repo with the `understudy_translations` table.
- `:translator` (required): a module that implements `Understudy.Translator`,
  or a `{module, opts}` tuple.
- `:source_locale`: the locale of your msgids. Defaults to `"en"`. Understudy
  does not translate this locale or its variants (`"en-GB"`, `"en_US"`).
- `:memory_cache`: keep translations in ETS. Defaults to `true`.

All other options go to `Gettext.Backend`.

## How it works

1. Gettext calls `handle_missing_translation/5` (or the plural version) for a
   message that is not in a `.po` file.
2. Understudy looks for the translation in ETS, then in the database.
3. If there is none, it calls the translator. It caches the result only if the
   result is valid:
   - it is not blank,
   - it has the same `%{}` placeholders as the source text (a plural form can
     omit `%{count}`),
   - a plural message has one form for each plural form of the locale.
4. If the translator fails, Gettext shows the source text. Understudy tries
   again on the next call.

For plural messages, the translator gets sample counts for each plural form
of the locale (for example `[[1, 21, 31], [2, 3, 4], [0, 5, 6]]` for Russian).
Understudy stores one row for each form.

## Your own translator

```elixir
defmodule MyApp.Translator do
  @behaviour Understudy.Translator

  @impl true
  def translate(%Understudy.Message{plural_text: nil} = message, _opts) do
    # return {:ok, translation} or {:error, reason}
  end

  def translate(%Understudy.Message{} = message, _opts) do
    # return {:ok, [form1, form2, ...]}, one form for each item in message.plural_examples
  end
end
```

## Tests in your app

The ETS cache is shared by all processes, and it does not know about the SQL
sandbox. A translation from one test can show in the next test. Do one of
these:

- set `memory_cache: false` in the test environment, or
- call `Understudy.MemoryCache.clear/0` in your test setup.

If you change or delete rows in `understudy_translations` while the app runs,
call `Understudy.MemoryCache.clear/0`.
