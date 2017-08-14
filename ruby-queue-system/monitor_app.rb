#!/usr/bin/env ruby

require 'logger'
require 'sinatra/base'
require 'redis'
require_relative 'config'
require_relative 'monitor'

$cost = 2
$max_age_seconds = 60
$monitor_interval = 1.0
$scan_size = 1000

class MonitorApp < Sinatra::Base
  configure {
    set :server, :puma
    set :port, 4562
  }

  @@monitor = nil

  def self.run!
    $logger.info "monitor server started"
    redis = Redis.new(:url => $redis_url)
    @@monitor = Monitor.new(redis, $cost, $max_age_seconds, $monitor_interval, $scan_size)
    @@monitor.start
    super
  end

  def self.quit!
    $logger.info "monitor server stopped"
    if @@monitor
      @@monitor.stop
    end
    Redis.current.disconnect!
    super
  end

  get '/' do
    return "Monitor - items moved to \"#{$priority_queue_name}\": #{@@monitor.move_count}"
  end

  run! if app_file == $0
end