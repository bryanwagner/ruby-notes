require 'logger'
require 'redis'
require 'json'
require_relative 'config'

class Producer
  attr_reader :items

  def initialize(redis)
    @redis = redis
    @items = Array.new
    @exit = false
    @task = nil
  end

  def reset
    @redis.flushall
    File.delete $output_file if File.exist? $output_file
  end

  def start
    reset

    @exit = false
    @task = Thread.new {
      read_input_file
      $logger.info "finished reading \"#{$input_file}\": items.length=#{@items.length}"

      time_sim = 0
      sim_start_timestamp = Time.now.to_f
      loop {
        break if @exit

        begin
          # produce items from our inbound queue to our outbound queue in realtime
          item = @items.shift
          if item
            time_in = item["time_in"]
            time_delta = time_in - time_sim
            time_sim += time_delta if time_delta > 0
            sleep_time = (sim_start_timestamp + time_sim) - Time.now.to_f
            sleep(sleep_time) if sleep_time > 0  # sleep according to realtime to avoid skew
            produce(item)
            $logger.info "produced: time_sim=#{time_sim}, item=#{item}"
          end
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

  def read_input_file
    @items.clear
    File.open($input_file, "r") { |file|
      file.each_line { |line|
        begin
          caller_id, time_in, time_to_handle = (line.split ",").map { |col| Integer col.strip}
          item = { "caller_id" => caller_id, "time_in" => time_in, "time_to_handle" => time_to_handle }
          @items.push item
        rescue ArgumentError => e
        end
      }
    }
    items.sort { |x, y|
      if x["time_in"] == y["time_in"]
        x["caller_id"] <=> y["caller_id"]
      else
        x["time_in"] <=> y["time_in"]
      end
    }
    return items
  end

  def produce(item)
    @redis.multi {
      timestamp = (Time.now.to_f * 1000).to_i
      @redis.set "item:#{item["caller_id"]}", item.to_json
      @redis.set "timestamp:#{item["caller_id"]}:#{timestamp}", item["caller_id"]
      key = "#{item["caller_id"]}:#{timestamp}"
      @redis.rpush $queue_name, key
    }
  end

end