require 'concurrent'
require_relative 'atomic_integer.rb'

class ThreadMonitorTest
  attr_reader :total_item_count

  def initialize(pool_size = 60)
    @pool_size = pool_size
    @item_count = AtomicInteger.new
    @total_item_count = AtomicInteger.new
    @mutex = Mutex.new
    @thread_monitor = ConditionVariable.new
    @exit = false
    @pool = nil
    @task = nil
  end

  def start
    @exit = false
    @pool = Concurrent::FixedThreadPool.new(@pool_size)
    @task = Thread.new {
      loop {
        # wait until workers are available (using wait/signal)
        #puts "loop begins"
        @mutex.synchronize {
          #puts "in synch block"
          while !@exit && @item_count.get >= @pool_size
            puts "main loop waiting: item_count=#{@item_count}"
            @thread_monitor.wait(@mutex)
          end
        }
        break if @exit

        # wait until items are available from the first queue and consume them
        #name, item = @redis.blpop @queue_name
        #@items.push JSON.parse item if item

        @item_count.incrementAndGet
        #puts "work added: item_count=#{@item_count}"
        @pool.post {
          #puts "work started: item_count=#{@item_count}"
          begin
            consume
          rescue => e
            $logger.error e.message
            e.backtrace.each { |line| $logger.error line }
          end
          @item_count.decrementAndGet
          @total_item_count.incrementAndGet
          puts "work finished: item_count=#{@item_count}"
          @thread_monitor.signal
        }
      }
    }
  end

  def stop
    @exit = true
    if @task
      @task.kill
      @task.join
    end
    if @pool
      @pool.shutdown
      @pool.wait_for_termination
      @pool = nil
    end
  end

  def consume
    sleep 1.0 * (rand 0.0...1.0)
  end

  if __FILE__ == $0
    test = ThreadMonitorTest.new
    test.start
    sleep(10)
    puts "SHUTTING DOWN TEST"
    test.stop
    puts test.total_item_count
  end
end