## Benchmarks

alias Distcount.{Counters, Repo}
alias Distcount.Counters.CounterLog

# Populate the counter "c0" with 10_000 records
1..10_000
|> Enum.map(fn _ ->
  dt = %{NaiveDateTime.utc_now() | microsecond: {0, 0}}

  %{key: "c0", value: 1, inserted_at: dt, updated_at: dt}
end)
|> Enum.chunk_every(100)
|> Enum.each(fn chunk ->
  Repo.insert_all(CounterLog, chunk)
end)

benchmarks = %{
  "incr" => fn counter ->
    Counters.incr(%CounterLog{key: counter, value: 1})
  end,
  "get_counter_value" => fn _counter ->
    Counters.get_counter_value("c0")
  end
}

Benchee.run(
  benchmarks,
  inputs: %{"ids" => for(i <- 1..100_000, do: "c#{i}")},
  before_each: &Enum.random/1,
  formatters: [
    {Benchee.Formatters.Console, comparison: false, extended_statistics: true},
    {Benchee.Formatters.HTML, extended_statistics: true, auto_open: false}
  ],
  print: [
    fast_warning: false
  ],
  parallel: 1,
  time: 30
)

Repo.delete_all(CounterLog)
