# DRbQueue

![](https://travis-ci.org/a-warner/drb_queue.png)

Simple separate-process queue system using DRb

## Motivation
Typical ruby web apps run background jobs with a separate-process / separate-server system like [Delayed Job](https://github.com/collectiveidea/delayed_job) or [Resque](https://github.com/resque/resque).  This strategy is convenient because there are many types of tasks that we don't want to or don't do during the course of a web request.  

If you don't want the overhead of managing a separate queue process / server / etc, then you can easily run background jobs in the same process as your webserver, but on a background thread, using something like [Girl Friday](https://github.com/mperham/girl_friday) or [Sucker Punch](https://github.com/brandonhilkert/sucker_punch).

Both of these libraries are optimized for truly concurrent rubies such as JRuby and Rubinius.  On MRI, every thread is competing for the [Global VM Lock](http://en.wikipedia.org/wiki/Global_Interpreter_Lock), and so you might have a background process or thread locking up a web request while it's doing some processing.

drb_queue basically has the same goal as `girl_friday`: execute background jobs within the same logical web server, for convenience, but it spins up a separate process for queue processing.  This strategy gives the queue and the web server each their own "global vm lock", so background jobs can't directly lock up web requests.  drb_queue uses DRb to simplify the inter-process interaction.

## Installation

Add this line to your application's Gemfile:

    gem 'drb_queue'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install drb_queue

## Usage

```ruby
# config/initializers/drb_queue.rb

Rails.configuration.after_initialize do
  require 'drb_queue/store/redis'

  DRbQueue.configure do |c|
    c.num_workers = (ENV['NUM_WORKERS'] || 0).to_i
    
    # what to do when a background job throws an error
    c.on_error { |e| do_something_with_a_drb_queue_error(e) }
    
    # drb_queue will store unfinished jobs in redis if you set a store
    c.store DRbQueue::Store::Redis, :redis => lambda { Redis.new }
  end

  DRbQueue.start!
end
```

See [Resque](https://github.com/resque/resque) for examples of workers; drb_queue workers are meant to work in exactly the same way. (except without queue names for the moment)

```ruby
# app/workers/user_registration_email_worker.rb
class UserRegistrationEmailWorker
  def self.perform(user_id)
    UserMailer.registration_email(User.find(user_id)).deliver
  end
end
```

And to queue up a job:

```ruby
DRbQueue.enqueue(UserRegistrationEmailWorker, user.id)
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

### LICENSE
MIT
