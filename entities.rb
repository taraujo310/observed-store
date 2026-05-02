require 'singleton'

module EmailService
  def self.notify(event, customer, order)
    puts "[EmailService] Enviando email '#{event}' para #{customer.email}"
  end
end

module InvoiceService
  def self.create(customer, order)
    puts "[InvoiceService] Criando nota fiscal para #{customer.name} no valor de #{order.total}"
  end
end

module PaymentService
  def self.process(order, method)
    puts "[PaymentService] Processando pagamento de #{order.total} via #{method}"
  end
end

Customer = Struct.new(:name, :email)
OrderItem = Struct.new(:product, :quantity) do
  def subtotal
    product.price * quantity
  end
end

class Order
  attr_reader :customer, :items, :status

  def initialize(customer:)
    @customer = customer
    @items = []
    @status = :pending
  end

  def add_item(item)
    @items << item
  end

  def total
    @items.sum(&:subtotal)
  end

  def pay!(method)
    raise "Pedido já pago" if @status == :paid
    raise "Pedido sem itens" if @items.empty?
    Stock.instance.validate_availability!(@items)

    PaymentService.process(self, method)
    confirm!
    @status = :paid
  end

  private

  def confirm!
    @items.each { |item| Stock.instance.decrease(item.product.name, quantity: item.quantity) }
    EmailService.notify(:order_confirmed, @customer, self)
    InvoiceService.create(@customer, self)
  end
end

class Product
  attr_reader :name, :price

  def initialize(name:, price:)
    @name = name
    @price = price
  end
end

class StoreService
  def initialize
    @orders = []
  end

  def list_products
    Stock.instance.products
  end

  def create_order(name:, email:)
    customer = Customer.new(name, email)
    order = Order.new(customer: customer)
    @orders << order
    order
  end

  def add_item(order, product_name, quantity)
    product_data = Stock.instance.products[product_name]
    raise "Produto não encontrado: #{product_name}" unless product_data
    raise "Estoque insuficiente para #{product_name}" unless Stock.instance.available?(product_name, quantity: quantity)

    item = OrderItem.new(product_data[:product], quantity)
    order.add_item(item)
    item
  end

  def pay_order(order, method)
    order.pay!(method)
  end
end

class Stock
  include Singleton

  def initialize
    @products = {}
  end

  def products
    @products
  end

  def add(product, quantity:)
    @products[product.name] = {product: product, quantity: quantity}
  end

  def decrease(product_name, quantity:)
    raise "Produto não encontrado: #{product_name}" unless @products.key?(product_name)

    @products[product_name][:quantity] -= quantity
  end

  def available?(product_name, quantity:)
    raise "Produto não encontrado: #{product_name}" unless @products.key?(product_name)

    @products[product_name][:quantity] >= quantity
  end

  def validate_availability!(items)
    items.each do |item|
      unless available?(item.product.name, quantity: item.quantity)
        raise "Estoque insuficiente para #{item.product.name}"
      end
    end
  end
end