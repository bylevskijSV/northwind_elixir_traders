defmodule NorthwindElixirTraders.Shipper do
  use Ecto.Schema
  import Ecto.Changeset
  alias NorthwindElixirTraders.{PhoneNumbers, Order}

  @name_mxlen 50
  @phone_mxlen 15

  schema "shippers" do
    field(:name, :string)
    field(:phone, :string)
    has_many(:orders, Order, on_replace: :nilify)

    timestamps(type: :utc_datetime)
  end

  def changeset(data, params \\ %{}) do
    permitted = [:id, :name, :phone]
    required = permitted |> List.delete(:id)

    data
    |> cast(params, permitted)
    |> validate_required(required)
    |> validate_length(:name, max: @name_mxlen)
    |> validate_length(:phone, max: @phone_mxlen)
    |> PhoneNumbers.validate_phone(:phone)
    |> unique_constraint([:name])
    |> unique_constraint([:id])
  end
end
