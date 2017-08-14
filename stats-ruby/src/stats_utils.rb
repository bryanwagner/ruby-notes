module StatsUtils

  FLOAT_PRECISION = 1e-6;
  POSITIVE_INFINITY = +1.0 / 0.0
  NEGATIVE_INFINITY = -1.0 / 0.0

  def self.equal?(a, b)
    (a - FLOAT_PRECISION) <= b && b <= (a + FLOAT_PRECISION)
  end

  # avoid allocating/deallocating arrays for simple functions
  def self.max(a, b)
    a > b ? a : b
  end

  def self.min(a, b)
    a < b ? a : b
  end

  def self.clamp(value, min, max)
    StatsUtils.max(min, StatsUtils.min(value, max))
  end

  # Stores running accumulators that can return the count, sum, min, max, average, and standard deviation of the values added.
  # 
  # The total counter keeps stats for all added values.
  # 
  # The varying counters act like a double-buffer the first counter flips to the second counter and resets
  # once its count reaches varying_count, and the second counter starts when the first counter reaches half the varying_count.
  # This way the varying counters are always staggered and resetting, which eliminates tail values from startup
  # and is more accurate to recent behavior.
  class Stats
    attr_reader :varying_count
    attr_reader :total
    attr_reader :varying
    attr_reader :varying_b

    def initialize(varying_count = 60)
      @varying_count = varying_count
      @total = StatsCounter.new
      @varying = StatsCounter.new
      @varying_b = StatsCounter.new
    end

    def set(stats_counter)
      @varying_count = stats_counter.varying_count
      @total.set(stats_counter.total)
      @varying.set(stats_counter.varying)
      @varying_b.set(stats_counter.varying_b)
    end

    def reset
      @total.reset
      @varying.reset
      @varying_b.reset
    end

    def add(value)
      @total.add(value)
      if @varying.count >= @varying_count
        temp = @varying
        @varying = @varying_b
        @varying_b = temp
        @varying_b.reset
      end
      @varying.add(value)
      if @varying.count > @varying_count / 2
        @varying_b.add(value)
      end
    end

    def to_s
      "varying=#{@varying}, total=#{@total}"
    end

    def inspect
      "<#{self.class}:" +
      " varying_count=#{@varying_count}" +
      ", total=#{@total.inspect}" +
      ", varying=#{@varying.inspect}" +
      ", varying_b=#{@varying_b.inspect}" +
      ">"
    end

  end

  # Stores running accumulators that can   the count, sum, min, max, average,
  # and standard deviation of the values added.
  class StatsCounter
    attr_reader :count
    attr_reader :last
    attr_reader :sum
    attr_reader :sum_squared
    attr_reader :min
    attr_reader :max

    def initialize
      reset
    end

    def set(statsCounter)
      @count = statsCounter.count
      @last = statsCounter.last
      @sum = statsCounter.sum
      @sum_squared = statsCounter.sum_squared
      @min = statsCounter.min
      @max = statsCounter.max
    end

    def reset
      @count = 0
      @last = 0.0
      @sum = 0.0
      @sum_squared = 0.0
      @min = StatsUtils::POSITIVE_INFINITY
      @max = StatsUtils::NEGATIVE_INFINITY
    end

    def average
      @count == 0 ? 0.0 : (@sum / @count)
    end

    def variance
      @count <= 1 ? 0.0 : StatsUtils.max(0.0, (@sum_squared - @sum * @sum / @count) / (@count - 1))
    end

    def stdev
      Math.sqrt(variance)
    end

    def unbiased_variance
      periods_inverse = 1.0 / @count
      @count <= 1 ? 0.0 : StatsUtils.max(0.0, periods_inverse * @sum_squared - (periods_inverse * @sum) * (periods_inverse * @sum))
    end

    def unbiased_stdev
      Math.sqrt(unbiased_variance)
    end

    def percent_of_min_max(value)
      divisor = @max - @min
      divisor == 0.0 ? 0.0 : StatsUtils.clamp((value - @min) / divisor, 0.0, 1.0)
    end

    def percent_of_stdev_from_average(value)
      stdev = stdev()
      stdev == 0.0 ? 0.0 : StatsUtils.clamp((value - average) / stdev, 0.0, 1.0)
    end

    def add(value)
      @count += 1
      @last = value
      @sum += value
      @sum_squared += value * value
      @min = StatsUtils.min(@min, value)
      @max = StatsUtils.max(@max, value)
    end

    def to_s
      "avg=#{average}, stdev=#{stdev}, count=#{@count}, last=#{@last}, min=#{@min}, max=#{@max}"
    end

    def inspect
      "<#{self.class}:" +
      " avg=#{average}" +
      ", stdev=#{stdev}" +
      ", count=#{@count}" +
      ", last=#{@last}" +
      ", min=#{@min}" +
      ", max=#{@max}" +
      ", sum=#{@sum}" +
      ", sum_squared=#{@sum_squared}" +
      ", variance=#{variance}" +
      ", unbiased_variance=#{unbiased_variance}" +
      ", unbiased_stdev=#{unbiased_stdev}" +
      ", percent_of_min_max(last)=#{percent_of_min_max(@last)}" +
      ", percent_of_stdev_from_average(last)=#{percent_of_stdev_from_average(@last)}" +
      ">"
    end

  end

end