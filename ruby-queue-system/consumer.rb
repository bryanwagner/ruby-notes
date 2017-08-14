require 'logger'
require 'redis'
require 'json'
require 'concurrent'
require_relative 'config'
require_relative 'atomic_integer'

class Consumer
  attr_reader :item_count
  attr_reader :total_item_count

  def initialize(redis, cost, pool_size = 8)
    @redis = redis
    @cost = cost
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
        @mutex.synchronize {
          while !@exit && @item_count.get >= @pool_size
            @thread_monitor.wait(@mutex)
          end
        }
        break if @exit

        # wait until items are available from the first queue and consume them
        name, key = @redis.blpop $queue_name

        @item_count.incrementAndGet
        @pool.post {
          begin
            consume(key)
          rescue => e
            $logger.error e.message
            e.backtrace.each { |line| $logger.error line }
          end
          @item_count.decrementAndGet
          @total_item_count.incrementAndGet
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
      # shut down the thread pool; wrap in a thread to avoid termination signal disallowing synchronization in 'trap context'
      mutex = Mutex.new
      thread = Thread.new {
        mutex.synchronize {
          @pool.shutdown
          @pool.wait_for_termination
          @pool = nil
        }
      }
      thread.join
    end
  end

  def consume(key)
    caller_id, timestamp = key.split ":"

    # remove the record as a transaction and check below so we process each item atomically with respect to the monitor
    result = @redis.multi {
      @redis.get "item:#{caller_id}"
      @redis.del "item:#{caller_id}"
      @redis.del "timestamp:#{key}"
    }
    json = result[0]
    if json
      item = JSON.parse json
      Utils.write_output(caller_id, timestamp, @cost)
      $logger.info "consumed: #{item}, cost: #{@cost}"
      time_to_handle = item["time_to_handle"]
      sleep time_to_handle
    end
  end

end