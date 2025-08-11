defmodule NorthwindElixirTraders.Insights do
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
    Joins
  }

  @timeout 10_000
  @max_concurrency 12

  @tables [Customer, Employee, Shipper, Category, Supplier, Product, OrderDetail, Order]
  @m_tables @tables -- [Order, OrderDetail]

  def query_entity_record_totals(m), do: Joins.p_od_group_and_select(m)
  def query_entity_by_product_quantity(m), do: Joins.p_od_group_and_select(m)
  def query_entity_by_order_revenue(m), do: Joins.p_od_group_and_select(m)

  def calculate_total_value_of_orders(orders, opts \\ [max_concurrency: @max_concurrency])
      when is_list(orders) and is_list(opts) do
    mc =
      if Keyword.has_key?(opts, :max_concurrency),
        do: Keyword.get(opts, :max_concurrency),
        else: @max_concurrency

    Task.async_stream(orders, &calculate_order_value/1,
      ordered: false,
      timeout: @timeout,
      max_concurrency: mc
    )
    |> Enum.to_list()
    |> Enum.sum_by(fn {_status, value} -> value end)
  end

  def list_top_n_customers_by_order_count(n \\ 5) when is_integer(n) do
    Customer
    |> join(:inner, [c], o in assoc(c, :orders))
    |> group_by([c, o], c.id)
    |> select([c, o], %{id: c.id, name: c.name, num_orders: count(o.id)})
    |> order_by([c, o], desc: count(o.id))
    |> limit(^n)
    |> Repo.all()
  end

  def list_customers_by_order_revenue do
    from(s in subquery(query_customers_by_order_revenue()),
      order_by: [desc: s.revenue]
    )
    |> Repo.all()
  end

  def query_customers_by_order_revenue, do: query_entity_by_order_revenue(Customer)

  def query_top_n_customers_by_order_revenue(n \\ 5) do
    query_top_n_entity_by_order_revenue(Customer, n)
  end

  def query_top_n_entity_by_order_revenue(m, n \\ 5) do
    query_top_n_entity_by(m, :revenue, n)
  end

  def query_top_n_entity_by(m, field, n \\ 5)
      when is_integer(n) and n >= 0 and field in [:quantity, :revenue] do
    from(s in subquery(query_entity_record_totals(m)),
      order_by: [desc: field(s, ^field)],
      limit: ^n
    )
  end

  def calculate_top_n_customers_by_order_value(n \\ 5) do
    calculate_top_n_entity_by_order_value(Customer, n)
  end

  def calculate_top_n_entity_by_order_value(m, n \\ 5) do
    calculate_top_n_entity_by(m, :revenue, n)
  end

  def calculate_top_n_entity_by(m, field, n \\ 5) do
    if n == 0,
      do: 0,
      else:
        from(s in subquery(query_top_n_entity_by(m, field, n)), select: sum(field(s, ^field)))
        |> Repo.one()
  end

  def count_customers_with_revenues do
    from(s in subquery(query_customers_by_order_revenue()),
      where: s.revenue > 0,
      select: count(s.id)
    )
    |> Repo.one()
  end

  def query_orders_by_customer(%Customer{id: customer_id}) do
    query_orders_by_customer(customer_id)
  end

  def query_orders_by_customer(customer_id) when not is_map(customer_id) do
    from(o in Order,
      join: c in Customer,
      on: o.customer_id == c.id,
      where: o.customer_id == ^customer_id,
      select: o
    )
  end

  def query_order_details_by_order(order_id) do
    join(OrderDetail, :inner, [od], p in Product, on: od.product_id == p.id)
    |> where([od], od.order_id == ^order_id)
  end

  def query_order_detail_values(order_id) do
    query_order_details_by_order(order_id)
    |> select([od, p], od.quantity * p.price)
  end

  def query_order_total_values(order_id) do
    query_order_details_by_order(order_id)
    |> select([od, p], sum(od.quantity * p.price))
  end

  def to_utc_datetime!(iso_date = %Date{}, :start),
    do: DateTime.new!(iso_date, ~T[00:00:00], "Etc/UTC")

  def to_utc_datetime!(iso_date = %Date{}, :end),
    do: DateTime.new!(iso_date, ~T[23:59:59], "Etc/UTC")

  def dollarize(cents) when is_number(cents), do: cents / 100

  def calculate_order_value(%Order{id: order_id}), do: calculate_order_value(order_id)

  def calculate_order_value(order_id) when not is_map(order_id) do
    order_id |> query_order_total_values() |> Repo.one()
  end

  def calculate_relative_revenue_share_of_entity_rows(m) do
    calculate_relative_share_of_entity_rows(m, :revenue)
  end

  def calculate_relative_share_of_entity_rows(m, field) do
    data =
      from(s in subquery(query_entity_record_totals(m)),
        order_by: [desc: field(s, ^field)]
      )
      |> Repo.all()

    total = Enum.sum_by(data, &Map.get(&1, field))

    Enum.map(data, fn x -> %{id: x.id, name: x.name, share: x[field] / total} end)
  end

  def trivial_many(m, q) when is_number(q) and q > 0 and q <= 1 do
    m
    |> calculate_relative_revenue_share_of_entity_rows
    |> Enum.reverse()
    |> Enum.take(count_entity_orders(m, :with) |> Kernel.*(q) |> round)
    |> Enum.sum_by(& &1.share)
  end

  def revenue_share_total_trivial_many(m, q \\ 0.8) do
    share_total_trivial_many(m, :revenue, q)
  end

  def share_total_trivial_many(m, field, q \\ 0.8) do
    calculate_relative_share_of_entity_rows(m, field)
    |> Enum.reverse()
    |> helper_vital_trivial(m, q)
  end

  def revenue_share_total_vital_few(m, q \\ 0.2) do
    share_total_vital_few(m, :revenue, q)
  end

  def share_total_vital_few(m, field, q \\ 0.2) do
    calculate_relative_share_of_entity_rows(m, field) |> helper_vital_trivial(m, q)
  end

  def helper_vital_trivial(data, m, q)
      when is_list(data) and m in @m_tables and is_number(q) and q > 0 and q <= 1 do
    n = m |> count_entity_orders() |> Kernel.*(q) |> round()
    data |> Enum.take(n) |> Enum.sum_by(& &1.share)
  end

  def count_customers_orders(condition \\ :with), do: count_entity_orders(Customer, condition)

  def generate_customer_share_of_revenue_xy do
    nc = count_customers_orders(:with)
    total = Order |> Repo.all() |> calculate_total_value_of_orders()

    Task.async_stream(0..nc, &{&1 / nc, calculate_top_n_customers_by_order_value(&1) / total})
    |> Enum.to_list()
    |> Enum.map(&elem(&1, 1))
  end

  def count_entity_orders(m, condition \\ :with)
      when m in @m_tables and condition in [:with, :without] do
    count_with =
      from(x in m)
      |> join(:inner, [x], o in assoc(x, :orders))
      |> select([x], x.id)
      |> distinct(true)
      |> Repo.aggregate(:count)

    case condition do
      :with -> count_with
      :without -> Repo.aggregate(m, :count) - count_with
    end
  end
end
