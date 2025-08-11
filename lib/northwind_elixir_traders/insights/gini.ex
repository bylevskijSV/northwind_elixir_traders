defmodule NorthwindElixirTraders.Insights.Gini do
  import Ecto.Query

  alias NorthwindElixirTraders.{
    Repo,
    Product,
    Order,
    OrderDetail,
    Customer,
    Employee,
    Shipper,
    Supplier,
    Category,
    Insights
  }

  defdelegate query_entity_by_order_revenue(m), to: Insights
  defdelegate count_entity_orders(m, condition), to: Insights
  defdelegate count_customers_orders(condition), to: Insights
  defdelegate calculate_top_n_entity_by(m, field, limit), to: Insights

  @tables [Customer, Employee, Shipper, Category, Supplier, Product, OrderDetail, Order]
  @m_tables @tables -- [Order, OrderDetail]

  def gini(m, field) do
    generate_entity_share_of_xy(m, field) |> calculate_gini_coeff()
  end

  def generate_customer_share_of_revenue_xy, do: generate_entity_share_of_revenue_xy(Customer)
  def generate_entity_share_of_revenues_xy(m), do: generate_entity_share_of_xy(m, :revenue)

  def generate_entity_share_of_xy(m, field) do
    0..count_entity_orders(m, :with)
    |> Task.async_stream(&{&1, calculate_top_n_entity_by(m, field, &1)})
    |> Enum.to_list()
    |> extract_task_results()
    |> normalize_xy()
  end

  def generate_entity_share_of_revenue_xy(m) when m in @m_tables do
    0..count_entity_orders(m, :with)
    |> Task.async_stream(&{&1, calculate_top_n_entity_by_order_value(m, &1)})
    |> Enum.to_list()
    |> extract_task_results()
    |> normalize_xy()
  end

  def calculate_top_n_entity_by_order_value(m, n \\ 5)
      when m in @m_tables and is_integer(n) and n >= 0 do
    if n == 0,
      do: 0,
      else:
        from(s in subquery(query_top_n_entity_by_order_revenue(m, n)),
          select: sum(s.revenue)
        )
        |> Repo.one()
  end

  def query_top_n_entity_by_order_revenue(m, n \\ 5)
      when m in @m_tables and is_integer(n) and n >= 0 do
    from(s in subquery(query_entity_by_order_revenue(m)), order_by: [desc: s.revenue], limit: ^n)
  end

  def extract_task_results(r) when is_list(r), do: Enum.map(r, &elem(&1, 1))

  defp calculate_gini_coeff(xyl) when is_list(xyl) do
    xyl
    |> then(&Enum.zip(&1, tl(&1)))
    |> Enum.reduce(0.0, fn c, acc -> acc + calculate_chunk_area(c) end)
    |> Kernel.-(0.5)
    |> Kernel.*(2)
  end

  defp calculate_chunk_area({{x1, y1}, {x2, y2}}) do
    {w, h} = {x2 - x1, y2 - y1}
    w * h * 0.5 + y1 * w
  end

  defp normalize_xy(xyl) when is_list(xyl) do
    {mxn, mxr} =
      xyl |> Enum.reduce({0, 0}, fn {n, r}, {mxn, mxr} -> {max(n, mxn), max(r, mxr)} end)

    xyl |> Enum.map(fn {n, r} -> {n / mxn, r / mxr} end)
  end
end
