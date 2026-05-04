module EventPublisher
  def subscribers
    @subscribers ||= []
  end

  def subscribe(subscriber)
    subscribers << subscriber
  end

  def unsubscribe(subscriber)
    subscribers.delete(subscriber)
  end

  def notify(event, data)
    frozen_data = data.freeze # Garante que os subscribers recebam dados imutáveis
    subscribers.each { |s| s.update(event, frozen_data) }
  end
end
