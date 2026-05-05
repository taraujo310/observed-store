require 'singleton'
require_relative './event_publisher'

module EmailService
  def self.update(event, data)
    case event
    when :payment_processing
      puts "[EmailService] Enviando email de recibo de processamento para #{data[:customer_email]}"
    when :order_confirmed
      puts "[EmailService] Enviando email de confirmação de compra para #{data[:customer_email]}"
    end
  end
end

module InvoiceService
  def self.update(event, data)
    return unless event == :order_confirmed

    puts "[InvoiceService] Criando nota fiscal para #{data[:customer_name]} no valor de R$#{data[:order_total]}"
  end
end

module PaymentService
  def self.update(event, data)
    return unless event == :payment_processing

    puts "[PaymentService] Processando pagamento de R$#{data[:order_total]} via #{data[:payment_method]}"
  end
end

Customer = Struct.new(:name, :email)
OrderItem = Struct.new(:product, :quantity) do
  def subtotal
    product.price * quantity
  end
end

class Order
  include EventPublisher

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

  def pay!(payment_method)
    raise "Pedido já pago" if @status == :paid
    raise "Pedido sem itens" if @items.empty?
    Stock.instance.validate_availability!(@items)

    # Order notifica a quem tiver ouvindo que está processando o pagamento
    notify(:payment_processing, {
      customer_email: customer.email,
      order_total: total,
      payment_method: payment_method
    })

    confirm!
    @status = :paid
  end

  private

  def confirm!
    # Order notifica a quem tiver ouvindo que o pedido foi confirmado
    notify(:order_confirmed, {
      customer_name: customer.name,
      customer_email: customer.email,
      items: items.map { |i| { product: i.product.name, quantity: i.quantity } }.freeze,
      order_total: total
    })
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

    # Inscreve os serviços para receber notificações do pedido
    order.subscribe(Stock.instance)
    order.subscribe(EmailService)
    order.subscribe(InvoiceService)
    order.subscribe(PaymentService)

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

  def pay_order(order, payment_method)
    order.pay!(payment_method)
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

  # O Stock agora é um especialista autônomo, ele decide quando agir ao ouvir o evento de confirmação do pedido
  def update(event, data)
    return unless event == :order_confirmed

    puts "[Stock] Baixando estoque para o pedido de #{data[:customer_name]}"

    data[:items].each do |item|
      decrease(item[:product], quantity: item[:quantity])
    end
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
