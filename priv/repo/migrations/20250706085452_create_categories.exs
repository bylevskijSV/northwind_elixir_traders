defmodule NorthwindElixirTraders.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories, primary_key: false) do
      add :category_id, :integer, primary_key: true
      add :name, :string
      add :description, :string
    end

    create unique_index(:categories, [:category_id])
  end
end
