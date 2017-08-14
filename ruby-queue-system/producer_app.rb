#!/usr/bin/env ruby

require 'logger'
require 'sinatra/base'
require 'redis'
require 'json'
require_relative 'config'
require_relative 'producer'

class ProducerApp < Sinatra::Base
  configure {
    set :server, :puma
    set :port, 4560
  }

  @@producer = nil

  def self.run!
    $logger.info "producer server started"
    redis = Redis.new(:url => $redis_url)
    @@producer = Producer.new(redis)
    @@producer.start
    super
  end

  def self.quit!
    $logger.info "producer server stopped"
    if @@producer
      @@producer.stop
    end
    Redis.current.disconnect!
    super
  end

  get '/' do
    return "Producer - items pending to produce to \"#{$queue_name}\": #{@@producer.items.length}"
  end

  run! if app_file == $0
end