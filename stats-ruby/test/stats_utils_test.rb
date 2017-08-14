#!/usr/bin/env ruby

require_relative "../src/stats_utils"
require 'test/unit'
require 'test/unit/ui/console/testrunner'

class StatsUtilsTest < Test::Unit::TestCase

  def self.run!
    test_suite = Test::Unit::TestSuite.new
    test_suite << StatsUtilsTest.new(:test_stats)
    test_suite << StatsUtilsTest.new(:test_timed_stats)
    Test::Unit::UI::Console::TestRunner.run(test_suite)
  end

  class AssertError < RuntimeError
  end

  def test_stats
    values = [
        1, 2, 3, 4, 5, 6, 7,
        1, 2, 3, 4, 5, 6, 7,
        1, 2, 3, 4, 5, 6, 7,
        1, 2, 3, 4, 5, 6, 7,
    ]
    stats = StatsUtils::Stats.new(6)
    values.each { |v| stats.add(v) }
    puts "stats: #{stats}"
    puts "stats.total:     #{stats.total}"
    puts "stats.varying:   #{stats.varying}"
    puts "stats.varying_b: #{stats.varying_b}"

    puts "checking total"
    assert(stats.total.count == 28)
    assert(StatsUtils.equal?(stats.total.last, 7.0))
    assert(StatsUtils.equal?(stats.total.min, 1.0))
    assert(StatsUtils.equal?(stats.total.max, 7.0))
    assert(StatsUtils.equal?(stats.total.average, 4.0))
    assert(StatsUtils.equal?(stats.total.stdev, 2.0367003088692623))

    puts "checking varying"
    assert(stats.varying.count == 4)
    assert(StatsUtils.equal?(stats.varying.last, 7.0))
    assert(StatsUtils.equal?(stats.varying.min, 4.0))
    assert(StatsUtils.equal?(stats.varying.max, 7.0))
    assert(StatsUtils.equal?(stats.varying.average, 5.5))
    assert(StatsUtils.equal?(stats.varying.stdev, 1.2909944487358056))

    puts "checking varying_b"
    assert(stats.varying_b.count == 1)
    assert(StatsUtils.equal?(stats.varying_b.last, 7.0))
    assert(StatsUtils.equal?(stats.varying_b.min, 7.0))
    assert(StatsUtils.equal?(stats.varying_b.max, 7.0))
    assert(StatsUtils.equal?(stats.varying_b.average, 7.0))
    assert(StatsUtils.equal?(stats.varying_b.stdev, 0.0))

    puts "test passed"
  end

  def time &block
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)  # Process::CLOCK_REALTIME
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - start_time
  end

  def mod_test_a(a, b)
    a % b
  end

  def mod_test_b(a, b)
    a - b * (a / b).to_i  # in statically typed languages with arithmetic operations, this is faster with integer casting; in Ruby, this is slower due to message sending
  end

  def test_timed_stats
    tests = 100
    iterations = 100_000
    timed_test = proc do |mod_method|  # test one of the mod methods
      iterations.times do  # multiple times so we get the average and stdev
        self.send(mod_method, rand, rand)  # run the test method
      end
    end
    stats_a = StatsUtils::Stats.new;
    stats_b = StatsUtils::Stats.new;

    puts "warmup tests: tests=#{tests}, iterations=#{iterations}"
    tests.times do
      timed_test.call(:mod_test_a)
      timed_test.call(:mod_test_b)
    end

    puts "running tests: tests=#{tests}, iterations=#{iterations}, mod_method=#{:mod_test_a}"
    tests.times do
      test_time = time { timed_test.call(:mod_test_a) }
      stats_a.add(test_time)
    end
    puts stats_a
    puts "running tests: tests=#{tests}, iterations=#{iterations}, mod_method=#{:mod_test_b}"
    tests.times do
      test_time = time { timed_test.call(:mod_test_b) }
      stats_b.add(test_time)
    end
    puts stats_b
  end

  run! if __FILE__ == $0
end