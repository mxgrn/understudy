defmodule Understudy.BackendTest do
  use Understudy.DataCase

  use Gettext, backend: Understudy.TestGettext

  setup do
    Gettext.put_locale(Understudy.TestGettext, "es")
    :ok
  end

  describe "singular messages" do
    test "returns the source text in the source locale" do
      Gettext.put_locale(Understudy.TestGettext, "en-GB")
      reject(&TestTranslator.translate/2)

      assert gettext("Start review") == "Start review"
    end

    test "translates a missing message with its locale, domain and context" do
      expect(TestTranslator, :translate, fn message, [] ->
        assert %Message{
                 text: "Add %{word}",
                 locale: "es",
                 source_locale: "en",
                 domain: "cards",
                 context: "button",
                 placeholders: [:word]
               } = message

        {:ok, "Añadir %{word}"}
      end)

      assert dpgettext("cards", "button", "Add %{word}", word: "casa") == "Añadir casa"
    end

    test "caches the translation in the database" do
      expect(TestTranslator, :translate, fn _message, _opts -> {:ok, "Empezar repaso"} end)

      assert gettext("Start review") == "Empezar repaso"
      Understudy.MemoryCache.clear()
      assert gettext("Start review") == "Empezar repaso"
    end

    test "keeps the translation in memory" do
      expect(TestTranslator, :translate, fn _message, _opts -> {:ok, "Empezar repaso"} end)

      assert gettext("Start review") == "Empezar repaso"
      TestRepo.delete_all(Translation)
      assert gettext("Start review") == "Empezar repaso"
    end

    test "does not keep the translation in memory when the memory cache is off" do
      backend = Understudy.TestGettextWithoutMemoryCache
      Gettext.put_locale(backend, "es")
      expect(TestTranslator, :translate, 2, fn _message, _opts -> {:ok, "Empezar repaso"} end)

      assert Gettext.gettext(backend, "Start review") == "Empezar repaso"
      TestRepo.delete_all(Translation)
      assert Gettext.gettext(backend, "Start review") == "Empezar repaso"
    end

    test "caches a translation for each context" do
      expect(TestTranslator, :translate, 2, fn
        %Message{context: "button"}, _opts -> {:ok, "Abrir"}
        %Message{context: nil}, _opts -> {:ok, "Abierto"}
      end)

      assert pgettext("button", "Open") == "Abrir"
      assert gettext("Open") == "Abierto"
    end

    test "falls back to the source text when the translator fails" do
      expect(TestTranslator, :translate, 2, fn _message, _opts -> {:error, :timeout} end)

      assert gettext("Hello, %{name}!", name: "Ana") == "Hello, Ana!"
      assert gettext("Hello, %{name}!", name: "Ana") == "Hello, Ana!"
    end

    test "falls back to the source text when the translation is blank" do
      expect(TestTranslator, :translate, fn _message, _opts -> {:ok, "  "} end)

      assert gettext("Start review") == "Start review"
      assert TestRepo.aggregate(Translation, :count) == 0
    end

    test "falls back to the source text when the placeholders do not match" do
      expect(TestTranslator, :translate, fn _message, _opts -> {:ok, "¡Hola, %{nombre}!"} end)

      assert gettext("Hello, %{name}!", name: "Ana") == "Hello, Ana!"
      assert TestRepo.aggregate(Translation, :count) == 0
    end
  end
end
