#!/usr/bin/env ruby

require 'logger'
require 'sinatra/base'
require 'redis'
require 'json'
require_relative 'config'
require_relative 'consumer'

$cost = 1
$pool_size = 1  # simulate a single agent

class ConsumerApp < Sinatra::Base
  configure {
    set :server, :puma
    set :port, 4561
  }

  @@consumer = nil

  def self.run!
    $logger.info "consumer server started"
    redis = Redis.new(:url => $redis_url)
    @@consumer = Consumer.new(redis, $cost, $pool_size)
    @@consumer.start
    super
  end

  def self.quit!
    $logger.info "consumer server stopped"
    if @@consumer
      @@consumer.stop
    end
    Redis.current.disconnect!
    super
  end

  get '/' do
    return "Consumer - items in progress: #{@@consumer.item_count}; total items consumed: #{@@consumer.total_item_count}"
  end

  run! if app_file == $0
end