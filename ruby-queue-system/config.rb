$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO
$redis_url = "redis://127.0.0.1:6379"
$output_file = "Output.csv"
$input_file = "QueueDataForTest.csv"
$queue_name = "queue:first"
$priority_queue_name = "queue:second"

class Utils
  
  def self.write_output(caller_id, timestamp, cost)
    time_waiting_millis = (Time.now.to_f * 1000).to_i - Integer(timestamp)
    time_waiting_seconds = time_waiting_millis / 1000
    File.open($output_file, 'a') { |file|
      file.flock(File::LOCK_EX)
      file.puts "#{caller_id},#{time_waiting_seconds},#{cost}\n"
    }
  end

end