defmodule UnderstudyTest do
  use Understudy.DataCase

  describe "translate/3" do
    test "translates dynamic text in the given locale and context" do
      expect(TestTranslator, :translate, fn %Message{locale: "de", context: "button"}, _opts ->
        {:ok, "Spanisch wiederholen"}
      end)

      assert Understudy.translate(Understudy.TestGettext, "Review Spanish",
               locale: "de",
               context: "button"
             ) ==
               "Spanisch wiederholen"
    end

    test "uses the current locale of the backend by default" do
      Gettext.put_locale(Understudy.TestGettext, "fr")

      expect(TestTranslator, :translate, fn %Message{locale: "fr"}, _opts ->
        {:ok, "Bien joué, %{name} !"}
      end)

      assert Understudy.translate(Understudy.TestGettext, "Well done, %{name}!",
               bindings: %{name: "Ana"}
             ) ==
               "Bien joué, Ana !"
    end
  end

  describe "prewarm/3" do
    @backend Understudy.TestGettextWithTemplates

    test "translates and caches the template messages that the locale's .po files do not have" do
      expect(TestTranslator, :translate, 4, fn
        %Message{text: "Flip", context: "button"}, _opts -> {:ok, "Voltear"}
        %Message{text: "Add %{word}"}, _opts -> {:ok, "Añadir %{word}"}
        %Message{text: "%{count} card"}, _opts -> {:ok, ["%{count} tarjeta", "%{count} tarjetas"]}
        %Message{text: "can't be blank", domain: "errors"}, _opts -> {:ok, "no puede estar vacío"}
      end)

      assert Understudy.prewarm(@backend, "es") == :ok

      assert TestRepo.all(Translation) |> Enum.map(& &1.value) |> Enum.sort() == [
               "%{count} tarjeta",
               "%{count} tarjetas",
               "Añadir %{word}",
               "Voltear",
               "no puede estar vacío"
             ]
    end

    test "also translates the messages that the .po files have when skip_translated is false" do
      stub(TestTranslator, :translate, fn
        %Message{text: "Start review"}, _opts -> {:ok, "Comenzar repaso"}
        %Message{plural_text: nil} = message, _opts -> {:ok, message.text}
        message, _opts -> {:ok, [message.text, message.plural_text]}
      end)

      assert Understudy.prewarm(@backend, "es", domains: ["default"], skip_translated: false) ==
               :ok

      assert TestRepo.get_by!(Translation, text: "Start review").value == "Comenzar repaso"
    end

    test "does not call the translator for messages that are in the database" do
      stub(TestTranslator, :translate, fn
        %Message{plural_text: nil} = message, _opts -> {:ok, message.text}
        message, _opts -> {:ok, [message.text, message.plural_text]}
      end)

      assert Understudy.prewarm(@backend, "es", skip_translated: false) == :ok
      Understudy.MemoryCache.clear()
      reject(&TestTranslator.translate/2)

      assert Understudy.prewarm(@backend, "es", skip_translated: false) == :ok
    end

    test "prewarms only the given domains" do
      expect(TestTranslator, :translate, fn %Message{domain: "errors"}, _opts ->
        {:ok, "no puede estar vacío"}
      end)

      assert Understudy.prewarm(@backend, "es", domains: ["errors"]) == :ok
    end

    test "returns the messages that it could not translate" do
      stub(TestTranslator, :translate, fn
        %Message{text: "Flip"}, _opts -> {:error, :timeout}
        %Message{plural_text: nil}, _opts -> {:ok, "Añadir %{word}"}
        _message, _opts -> {:ok, ["%{count} tarjeta", "%{count} tarjetas"]}
      end)

      assert Understudy.prewarm(@backend, "es", domains: ["default"]) ==
               {:error, [{"default", "button", "Flip"}]}
    end

    test "raises for the source locale" do
      assert_raise ArgumentError, fn -> Understudy.prewarm(@backend, "en-GB") end
    end
  end
end
