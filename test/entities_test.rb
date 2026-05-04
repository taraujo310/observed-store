# frozen_string_literal: true

require_relative "test_helper"

module StockSetup
  def setup_stock
    Stock.instance.products.clear
    Stock.instance.add(Product.new(name: "Laptop", price: 1000), quantity: 10)
    Stock.instance.add(Product.new(name: "Mouse", price: 25), quantity: 5)
  end
end

class ProductTest < Minitest::Test
  def test_has_name_and_price
    product = Product.new(name: "Laptop", price: 1000)

    assert_equal "Laptop", product.name
    assert_equal 1000, product.price
  end
end

class OrderItemTest < Minitest::Test
  def test_calculates_subtotal
    product = Product.new(name: "Mouse", price: 25)
    item = OrderItem.new(product, 3)

    assert_equal 75, item.subtotal
  end
end

class StockTest < Minitest::Test
  include StockSetup

  def setup
    setup_stock
  end

  def test_adds_product
    assert_equal 2, Stock.instance.products.size
    assert_equal 10, Stock.instance.products["Laptop"][:quantity]
  end

  def test_available_when_stock_sufficient
    assert Stock.instance.available?("Laptop", quantity: 5)
  end

  def test_not_available_when_stock_insufficient
    refute Stock.instance.available?("Laptop", quantity: 11)
  end

  def test_decreases_stock
    Stock.instance.decrease("Laptop", quantity: 3)

    assert_equal 7, Stock.instance.products["Laptop"][:quantity]
  end

  def test_available_raises_for_unknown_product
    error = assert_raises(RuntimeError) { Stock.instance.available?("Tablet", quantity: 1) }
    assert_equal "Produto não encontrado: Tablet", error.message
  end

  def test_decrease_raises_for_unknown_product
    error = assert_raises(RuntimeError) { Stock.instance.decrease("Tablet", quantity: 1) }
    assert_equal "Produto não encontrado: Tablet", error.message
  end
end

class OrderTest < Minitest::Test
  include StockSetup

  def setup
    setup_stock
    @customer = Customer.new("João", "joao@email.com")
    @order = Order.new(customer: @customer)

    @order.subscribe(Stock.instance)
  end

  def test_starts_with_pending_status
    assert_equal :pending, @order.status
  end

  def test_starts_with_no_items
    assert_empty @order.items
  end

  def test_adds_items
    product = Stock.instance.products["Laptop"][:product]
    @order.add_item(OrderItem.new(product, 2))

    assert_equal 1, @order.items.size
  end

  def test_calculates_total
    laptop = Stock.instance.products["Laptop"][:product]
    mouse = Stock.instance.products["Mouse"][:product]
    @order.add_item(OrderItem.new(laptop, 1))
    @order.add_item(OrderItem.new(mouse, 2))

    assert_equal 1050, @order.total
  end

  def test_pay_changes_status_to_paid
    laptop = Stock.instance.products["Laptop"][:product]
    @order.add_item(OrderItem.new(laptop, 1))

    @order.pay!(:pix)

    assert_equal :paid, @order.status
  end

  def test_pay_decreases_stock
    laptop = Stock.instance.products["Laptop"][:product]
    @order.add_item(OrderItem.new(laptop, 2))

    @order.pay!(:pix)

    assert_equal 8, Stock.instance.products["Laptop"][:quantity]
  end

  def test_pay_raises_if_already_paid
    laptop = Stock.instance.products["Laptop"][:product]
    @order.add_item(OrderItem.new(laptop, 1))
    @order.pay!(:pix)

    error = assert_raises(RuntimeError) { @order.pay!(:pix) }
    assert_equal "Pedido já pago", error.message
  end

  def test_pay_raises_if_no_items
    error = assert_raises(RuntimeError) { @order.pay!(:pix) }
    assert_equal "Pedido sem itens", error.message
  end

  def test_pay_raises_if_insufficient_stock
    laptop = Stock.instance.products["Laptop"][:product]
    @order.add_item(OrderItem.new(laptop, 11))

    error = assert_raises(RuntimeError) { @order.pay!(:pix) }
    assert_match(/Estoque insuficiente/, error.message)
    assert_equal :pending, @order.status
  end
end

class StoreServiceTest < Minitest::Test
  include StockSetup

  def setup
    setup_stock
    @store = StoreService.new
  end

  def test_list_products
    assert_equal 2, @store.list_products.size
    assert_includes @store.list_products.keys, "Laptop"
  end

  def test_create_order
    order = @store.create_order(name: "Maria", email: "maria@email.com")

    assert_equal "Maria", order.customer.name
    assert_equal "maria@email.com", order.customer.email
    assert_equal :pending, order.status
  end

  def test_add_item_to_order
    order = @store.create_order(name: "Maria", email: "maria@email.com")
    @store.add_item(order, "Laptop", 1)

    assert_equal 1, order.items.size
    assert_equal 1000, order.total
  end

  def test_add_item_raises_for_unknown_product
    order = @store.create_order(name: "Maria", email: "maria@email.com")

    error = assert_raises(RuntimeError) { @store.add_item(order, "Tablet", 1) }
    assert_equal "Produto não encontrado: Tablet", error.message
  end

  def test_add_item_raises_for_insufficient_stock
    order = @store.create_order(name: "Maria", email: "maria@email.com")

    error = assert_raises(RuntimeError) { @store.add_item(order, "Mouse", 6) }
    assert_equal "Estoque insuficiente para Mouse", error.message
  end

  def test_full_order_flow
    order = @store.create_order(name: "Maria", email: "maria@email.com")
    @store.add_item(order, "Laptop", 2)
    @store.add_item(order, "Mouse", 3)

    assert_equal 2075, order.total

    @store.pay_order(order, :cartao)

    assert_equal :paid, order.status
    assert_equal 8, Stock.instance.products["Laptop"][:quantity]
    assert_equal 2, Stock.instance.products["Mouse"][:quantity]
  end
end
