require 'logger'
require 'redis'
require 'json'
require_relative 'config'

class Monitor
  attr_reader :move_count

  def initialize(redis, cost, max_age_seconds, monitor_interval, scan_size)
    @redis = redis
    @cost = cost
    @max_age_seconds = max_age_seconds
    @monitor_interval = monitor_interval
    @scan_size = scan_size
    @move_count = 0
    @exit = false
    @task = nil
  end

  def start
    @exit = false
    @task = Thread.new {
      loop {
        break if @exit
        sleep @monitor_interval

        begin
          monitor
        rescue => e
          $logger.error e.message
          e.backtrace.each { |line| $logger.error line }
        end
      }
    }
  end

  def stop
    @exit = true
    if @task
      @task.kill
      @task.join
    end
  end

  def monitor
    cursor = 0
    old_items = Array.new
    loop {
      cursor_result, scan_keys = @redis.scan cursor, { :match => "timestamp*", :count => @scan_size }
      cursor = Integer(cursor_result)
      scan_keys.each { |scan_key|
        name, caller_id, timestamp = scan_key.split ":"
        now = (Time.now.to_f * 1000).to_i
        age_seconds = (now - Integer(timestamp)) / 1000.0
        old_items.push("#{caller_id}:#{timestamp}") if age_seconds >= @max_age_seconds
      }
      break if cursor == 0
    }

    $logger.debug "monitor: old_items.length=#{old_items.length}"
    old_items.each { |key|

      # remove the record as a transaction and check below so we process each item atomically with respect to the primary consumer
      del_result, lrem_result, rpush_result = @redis.multi {
        @redis.del "timestamp:#{key}"
        @redis.lrem $queue_name, 1, key
      }
      if Integer(lrem_result) > 0
        @redis.rpush $priority_queue_name, key  # move after confirming atomic delete
        caller_id, timestamp = key.split ":"
        Utils.write_output(caller_id, timestamp, @cost)
        @move_count += 1
        $logger.info "moved: #{key}, cost: #{@cost}"
      end
    }
  end

end