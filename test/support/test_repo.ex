defmodule Understudy.TestRepo do
  use Ecto.Repo, otp_app: :understudy, adapter: Ecto.Adapters.Postgres
end

defmodule Understudy.TestMigration do
  use Ecto.Migration

  def up, do: Understudy.Migration.up()
  def down, do: Understudy.Migration.down()
end
