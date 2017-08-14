class AtomicInteger

  def initialize(value = 0)
    @mutex = Mutex.new
    @value = value
  end

  def get
    value = @mutex.synchronize { @value }
    return value
  end

  def getAndIncrement
    old_value = @mutex.synchronize {
      old_value = @value
      @value += 1
      old_value
    }
    return old_value
  end

  def getAndDecrement
    old_value = @mutex.synchronize {
      old_value = @value
      @value -= 1
      old_value
    }
    return old_value
  end

  def set(value)
    Integer(value)  # raise error if not integer
    old_value = @mutex.synchronize {
      old_value = @value
      @value = value
      old_value
    }
    return old_value
  end

  def incrementAndGet
    value = @mutex.synchronize { @value += 1 }
    return value
  end

  def decrementAndGet
    value = @mutex.synchronize { @value -= 1 }
    return value
  end

  def to_s
    get.to_s
  end

end