Application.put_env(:understudy, Understudy.TestRepo,
  url: "ecto://postgres:postgres@localhost/understudy_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  log: false
)

_ = Ecto.Adapters.Postgres.storage_up(Understudy.TestRepo.config())
{:ok, _} = Understudy.TestRepo.start_link()

Ecto.Migrator.run(Understudy.TestRepo, [{1, Understudy.TestMigration}], :up,
  all: true,
  log: false
)

Ecto.Adapters.SQL.Sandbox.mode(Understudy.TestRepo, :manual)

Mimic.copy(Understudy.TestTranslator)
Mimic.copy(ReqLLM)

ExUnit.start(capture_log: true)
