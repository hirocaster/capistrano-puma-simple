# Capistrano::PumaSimple

Puma control by Capistrano

## Installation

Add this line to your application's Gemfile:

    gem 'capistrano-puma-simple'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install capistrano-puma-simple

## Usage

```
# in Capfile
require "capistrano/puma-simple"

```

then you can use `cap -T` to list tasks

```
cap puma:config          # Setup puma config file
cap puma:halt            # Halt puma
cap puma:phased-restart  # Phased-restart puma
cap puma:restart         # Restart puma
cap puma:start           # Start puma
cap puma:status          # Status puma
cap puma:stop            # Stop puma
cap puma:template        # Export template file
```

you may want to customize `puma.rb` export template file

```
cap puma:template        # Export template file
``

customize to `config/deploy/templates/puma.rb.erb`

Configurable options, shown here with defaults:

```
set :puma_role, :app
set :puma_env, -> { fetch(:rack_env, fetch(:rails_env, fetch(:stage))) }
set :puma_rackup, -> { File.join(current_path, "config.ru") }
set :puma_conf, -> { File.join(shared_path, "puma.rb") }
set :puma_pid, -> { File.join(shared_path, "tmp", "pids", "puma.pid") }
set :puma_state, -> { File.join(shared_path, "tmp", "pids", "puma.state") }
set :puma_access_log, -> { File.join(shared_path, "log", "puma_access.log") }
set :puma_error_log, -> { File.join(shared_path, "log", "puma_error.log") }
set :puma_threads, [0, 16]
set :puma_workers, 0
set :puma_bind, "tcp://0.0.0.0:9292"
set :puma_default_control_app, -> { File.join("unix://#{shared_path}", "tmp", "sockets", "pumactl.sock") }
set :puma_tag, -> { fetch(:application) }
set :puma_worker_timeout, 60
set :puma_init_active_record, false
set :puma_preload_app, false
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
