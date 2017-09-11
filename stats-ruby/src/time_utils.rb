require 'time'

module TimeUtils

  def self.start
    Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)  # Process::CLOCK_REALTIME
  end

  def self.stop_seconds(start_nanos)
    (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - start_nanos) * 1e-9
  end

  def self.stop_millis(start_nanos)
    (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - start_nanos) * 1e-6
  end

  def self.stop_nanos(start_nanos)
    (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - start_nanos)
  end

  def self.seconds &block
    start_nanos = start
    yield
    stop_seconds(start_nanos)
  end

  def self.millis &block
    start_nanos = start
    yield
    stop_millis(start_nanos)
  end

  def self.nanos &block
    start_nanos = start
    yield
    stop_nanos(start_nanos)
  end
end