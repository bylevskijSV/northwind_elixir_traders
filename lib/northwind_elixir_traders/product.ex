defmodule NorthwindElixirTraders.Product do
  use Ecto.Schema
  import Ecto.Changeset
  alias NorthwindElixirTraders.{Category, Supplier, OrderDetail, Validations}

  @name_mxlen 50

  schema "products" do
    field(:name, :string)
    field(:unit, :string)
    field(:price, :float)

    belongs_to(:category, Category)
    belongs_to(:supplier, Supplier)
    has_many(:order_details, OrderDetail)

    timestamps(type: :utc_datetime)
  end

  def changeset(data, params \\ %{}) do
    permitted = [:id, :name, :unit, :price, :category_id, :supplier_id]
    required = permitted |> List.delete(:id)

    data
    |> cast(params, permitted)
    |> validate_required(required)
    |> validate_length(:name, max: @name_mxlen)
    |> Validations.validate_foreign_key_id(Category, :category_id)
    |> Validations.validate_foreign_key_id(Supplier, :supplier_id)
    |> unique_constraint([:name])
    |> unique_constraint([:id])
  end
end
