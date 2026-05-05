# frozen_string_literal: true

require_relative "test_helper"

class SubjectMock
  include EventPublisher
end

# Classe auxiliar para atuar como o "Observer" (Assinante)
class ObserverMock
  attr_reader :received_event, :received_data, :call_count

  def initialize
    @call_count = 0
  end

  def update(event, data)
    @received_event = event
    @received_data = data
    @call_count += 1
  end
end

class EventPublisherTest < Minitest::Test
  def setup
    @subject = SubjectMock.new
    @observer = ObserverMock.new
  end

  def test_should_notify_subscriber
    @subject.subscribe(@observer)
    @subject.notify(:test_event, { info: "contexto" })

    assert_equal :test_event, @observer.received_event
    assert_equal "contexto", @observer.received_data[:info]
    assert_equal 1, @observer.call_count
  end

  def test_should_not_subscribe_duplicate_observers
    @subject.subscribe(@observer)
    @subject.subscribe(@observer)

    @subject.notify(:event, {})
    assert_equal 1, @observer.call_count, "O observador não deveria ser notificado duas vezes"
  end

  def test_should_unsubscribe_correctly
    @subject.subscribe(@observer)
    @subject.unsubscribe(@observer)

    @subject.notify(:event, {})
    assert_equal 0, @observer.call_count
  end

  def test_should_enforce_deep_freeze_immutability
    data = {
      order: "123",
      items: [{ product: "Laptop", price: 1000 }]
    }

    @subject.subscribe(@observer)
    @subject.notify(:order_confirmed, data)

    # Valida se o Hash principal está congelado
    assert @observer.received_data.frozen?

    # Valida se o Array interno e os objetos dentro dele estão congelados (Deep Freeze)
    assert @observer.received_data[:items].frozen?
    assert @observer.received_data[:items].first.frozen?

    # Tenta mutar e espera um FrozenError
    assert_raises(FrozenError) do
      @observer.received_data[:items].first[:price] = 0
    end
  end

  def test_subscribers_list_should_be_private
    assert_raises(NoMethodError) do
      @subject.subscribers # Não deve permitir acesso externo à lista
    end
  end
end
