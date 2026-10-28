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
end
