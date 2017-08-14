# Queue System

> For the program you create you should have 3 processes. One reads the input and puts the people in queue, 
> one that removes people from the queue and processes them (this should only simulate one agent) and 
> another that moves them to the priority queue. Each must be able to run on separate computers. The output 
> should also be in CSV and should contain the caller's ID, the time waiting to be served and the cost of 
> the call.

## Overview

The queues above operate on `item`s, which contain the information associated with a caller.  The physical queues are implemented by a Redis server.  There are three Redis key schemes:

1. `queue:#{name}` contains FIFO queues of items to process
2. `item:#{caller_id}` contains the item hash serialized to JSON
3. `timestamp:#{caller_id}:#{timestamp}` marks caller IDs with their time of arrival in the key, which is used with Redis SCAN to find expired unprocessed items

The Queue Producer, Queue Consumer, and Queue Monitor operate in simulated realtime.  They run in a minimal Sinatra/Puma stack where process information is output by the server root endpoint GET mapping.  Atomic operations in Redis are performed using MULTI and EXEC, which is implemented with a block passed to the `Redis::multi` method.

The Queue Producer, when started, will reset the simulation, invoking Redis FLUSHALL and deleting `Output.csv`.

The Queue Consumer is implemented with a thread pool; where each thread represents an `agent` and the work is simulated with calls to `sleep`.  A counting semaphore is used to limit the consumer's capacity; the consumer will pause consumption while the capacity is full using the wait/signal pattern.  At first, I missed the idea of having a single agent, so the concurrency is set to 1 worker thread.  The number of working agents can be changed by setting the `$pool_size` global in `consumer_app.rb`.

The Queue Monitor is a daemon task that runs once per second running Redis SCAN on the `timestamp*` keys.  We scan on the keys to avoid locking the entire redis server.  When expired items are detected, a MULTI EXEC transaction executes which attempts to atomically remove the items from the first queue.  The item is added to the second priority queue if and only if this process succeeds.

## Files

- `config.rb` defines globals for configuration
- `producer_app.rb` runs the Queue Producer server
- `consumer_app.rb` runs the Queue Consumer server
- `monitor_app.rb` runs the Queue Monitor server
- `producer.rb` contains the Producer business logic
- `consumer.rb` contains the Consumer business logic
- `monitor.rb` contains the Monitor business logic
- `atomic_integer.rb` contains an AtomicInteger implementation, used for semaphores

## Running

After configuring `config.rb`, start the servers in order:

```
ruby monitor_app.rb
ruby consumer_app.rb
ruby producer_app.rb
```

By default, input will be parsed from `QueueDataForTest.csv` and output will be written to `Output.csv`.