defmodule NorthwindElixirTraders.Country do
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias NorthwindElixirTraders.Repo

  @url "https://raw.githubusercontent.com/datasets/country-codes/2ed03b6993e817845c504ce9626d519376c8acaa/data/country-codes.csv"

  @name_mxlen 50
  @dial_mxlen 14

  schema "countries" do
    field(:name, :string)
    field(:dial, :string)
    field(:alpha3, :string)

    timestamps(type: :utc_datetime)
  end

  def import_changeset(data, params \\ %{}) do
    permitted = [:name, :dial, :alpha3]
    required = permitted

    data
    |> cast(params, permitted)
    |> validate_required(required)
    |> validate_length(:name, max: @name_mxlen)
    |> validate_length(:dial, max: @dial_mxlen)
    |> validate_length(:alpha3, is: 3)
    |> unique_constraint([:name])
  end

  def get_dial_by(field, value) when is_atom(field) and is_bitstring(value) do
    criterion = Keyword.new([{field, value}])
    Repo.one(from(c in __MODULE__, where: ^criterion, select: c.dial))
  end

  def get_dial(value) when is_bitstring(value) do
    dialcodes =
      [:name, :alpha3] |> Enum.map(&get_dial_by(&1, value)) |> Enum.filter(&(not is_nil(&1)))

    case dialcodes do
      [a, a] -> a
      [a] -> a
      [] -> nil
      [_a, _b] -> nil
    end
  end

  def import(),
    do: get_csv_rows() |> process_csv() |> Enum.map(&csv_to_tuple_to_record/1)

  defp csv_to_tuple_to_record({_name, _dial, _alpha3} = country) do
    [:name, :dial, :alpha3]
    |> Enum.zip(Tuple.to_list(country))
    |> Map.new()
    |> then(&import_changeset(struct(__MODULE__), &1))
    |> Repo.insert()
  end

  defp get_csv_rows() do
    {status, result} = :httpc.request(@url)

    case {status, result} do
      {:ok, {_status, _headers, body}} ->
        {:ok,
         body
         |> List.to_string()
         |> String.split("\n")
         |> Enum.map(&fix_csv_row/1)
         |> Enum.map(&String.split(&1, ","))}

      {:error, {status, _, _}} ->
        {:error, status}
    end
  end

  defp fix_csv_row(row) when is_bitstring(row) do
    regex = ~r/"([^"]*)"/
    String.replace(row, regex, &(String.replace(&1, ",", "|") |> String.replace("\"", "")))
  end

  defp process_csv({:ok, [headings | data]}) do
    indices =
      ["CLDR display name", "Dial", "ISO3166-1-Alpha-3"]
      |> Enum.map(fn colname -> Enum.find_index(headings, &(&1 == colname)) end)

    data
    |> Enum.map(fn row -> Enum.map(indices, &Enum.at(row, &1)) end)
    |> Enum.filter(fn r -> "" not in r and nil not in r end)
    |> Enum.map(&List.to_tuple(&1))
    |> Enum.map(fn {country, dial, iso} -> {country, String.replace(dial, "-", ""), iso} end)
  end
end
