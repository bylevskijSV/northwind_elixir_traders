# NorthwindElixirTraders

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `northwind_elixir_traders` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:northwind_elixir_traders, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/northwind_elixir_traders>.

## Star up

You need only docker:

```sh
./build-and-start-app.sh
```

Exec in container:

```sh
docker exec -it northwind_elixir_traders_app sh
```

This project uses the SQLite3 database. Create a database file called northwind_elixir_traders_repo.db with the following schema structure:

```elixir
mix ecto.create && mix ecto.migrate
```

[Schema reference.](https://dbdiagram.io/d/Northwind-Traders-65d359a0ac844320ae7abb2a)
