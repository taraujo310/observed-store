module EventPublisher
  def subscribe(subscriber)
    subscribers << subscriber unless subscribers.include?(subscriber)
  end

  def unsubscribe(subscriber)
    subscribers.delete(subscriber)
  end

  def notify(event, data)
    frozen_data = deep_freeze(data) # Garante que os subscribers recebam dados imutáveis
    subscribers.each { |s| s.update(event, frozen_data) }
  end

  private
  # Mantém a lista de subscribers encapsulada para evitar modificações externas
  def subscribers
    @subscribers ||= []
  end

  def deep_freeze(obj)
    case obj
    when Hash then obj.each_value { |v| deep_freeze(v) }.freeze
    when Array then obj.each { |v| deep_freeze(v) }.freeze
    else obj.freeze
    end
  end
end
