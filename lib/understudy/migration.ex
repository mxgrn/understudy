defmodule Understudy.Migration do
  @moduledoc """
  Creates the table for the translations.

  Call it from a migration in your app:

      defmodule MyApp.Repo.Migrations.AddUnderstudy do
        use Ecto.Migration

        def up, do: Understudy.Migration.up()
        def down, do: Understudy.Migration.down()
      end
  """
  use Ecto.Migration

  def up do
    create table(:understudy_translations) do
      add(:locale, :text, null: false)
      add(:domain, :text, null: false)
      add(:context, :text, null: false, default: "")
      add(:text, :text, null: false)
      add(:plural_text, :text)
      add(:text_hash, :binary, null: false)
      add(:plural_index, :integer, null: false, default: 0)
      add(:value, :text, null: false)

      timestamps()
    end

    create(
      unique_index(:understudy_translations, [
        :locale,
        :domain,
        :context,
        :text_hash,
        :plural_index
      ])
    )
  end

  def down do
    drop(table(:understudy_translations))
  end
end
