defmodule Understudy.TestTranslator do
  @behaviour Understudy.Translator

  @impl true
  def translate(_message, _opts), do: raise("stub this function with Mimic")
end

defmodule Understudy.TestGettext do
  use Understudy.Backend,
    otp_app: :understudy,
    repo: Understudy.TestRepo,
    translator: Understudy.TestTranslator
end

defmodule Understudy.TestGettextWithoutMemoryCache do
  use Understudy.Backend,
    otp_app: :understudy,
    repo: Understudy.TestRepo,
    translator: Understudy.TestTranslator,
    memory_cache: false
end

defmodule Understudy.TestGettextWithTemplates do
  use Understudy.Backend,
    otp_app: :understudy,
    priv: Path.expand("gettext", __DIR__),
    repo: Understudy.TestRepo,
    translator: Understudy.TestTranslator
end
