namespace :load do
  task :defaults do
    set :puma_default_hooks, true
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
  end
end

namespace :deploy do
  before :starting, :check_puma_hooks do
    invoke "puma:add_default_hooks" if fetch(:puma_default_hooks)
  end
end

namespace :puma do
  task :add_default_hooks do
    after "deploy:check", "puma:check"
    after "deploy:finished", "puma:smart_restart"
  end

  task :check do
    on roles fetch(:puma_role) do |_role|
      unless  test "[ -f #{fetch(:puma_conf)} ]"
        warn "puma.rb NOT FOUND!"
        invoke "puma:config"
        info "puma.rb generated"
      end
    end
  end

  desc "Export template file"
  task :template do
    FileUtils.mkdir_p "config/deploy/templates/" unless File.exist? "config/deploy/templates/"
    FileUtils.cp File.expand_path("../../templates/puma.rb.erb", __FILE__), "config/deploy/templates/puma.rb.erb"
  end

  desc "Setup puma config file"
  task :config do
    on roles(fetch(:puma_role)) do |role|
      template_puma role
    end
  end

  desc "Start puma"
  task :start do
    on roles fetch(:puma_role) do |role|
      puma_switch_user(role) do
        if test "[ -f #{fetch(:puma_conf)} ]"
          info "using conf file #{fetch(:puma_conf)}"
        else
          invoke "puma:config"
        end
        within current_path do
          with rack_env: fetch(:puma_env) do
            execute :bundle, :exec, :puma, "-C #{fetch(:puma_conf)} --daemon"
          end
        end
      end
    end
  end

  %w(halt stop status).map do |command|
    desc "#{command.capitalize} puma"
    task command do
      on roles fetch(:puma_role) do |role|
        within current_path do
          puma_switch_user(role) do
            with rack_env: fetch(:puma_env) do
              if test "[ -f #{fetch(:puma_pid)} ]"
                if test :kill, "-0 $( cat #{fetch(:puma_pid)} )"
                  execute :bundle, :exec, :pumactl, "-S #{fetch(:puma_state)} -F #{fetch(:puma_conf)} #{command}"
                else
                  # delete invalid pid file , process is not running.
                  execute :rm, fetch(:puma_pid)
                end
              else
                # pid file not found, so puma is probably not running or it using another pidfile
                warn "Puma not running"
              end
            end
          end
        end
      end
    end
  end

  %w(phased-restart restart).map do |command|
    desc "#{command.capitalize} puma"
    task command do
      on roles fetch(:puma_role) do |role|
        within current_path do
          puma_switch_user(role) do
            with rack_env: fetch(:puma_env) do
              if (test "[ -f #{fetch(:puma_pid)} ]") && (test :kill, "-0 $( cat #{fetch(:puma_pid)} )")
                # NOTE pid exist but state file is nonsense, so ignore that case
                execute :bundle, :exec, :pumactl, "-S #{fetch(:puma_state)} -F #{fetch(:puma_conf)} #{command}"
              else
                # Puma is not running or state file is not present : Run it
                invoke "puma:start"
              end
            end
          end
        end
      end
    end
  end

  task :smart_restart do
    if !fetch(:puma_preload_app) && fetch(:puma_workers).to_i > 1
      invoke "puma:phased-restart"
    else
      invoke "puma:restart"
    end
  end

  def puma_bind
    Array(fetch(:puma_bind)).collect do |bind|
      "bind '#{bind}'"
    end.join("\n")
  end

  def puma_switch_user(role, &block)
    user = puma_user(role)
    if user == role.user
      block.call
    else
      as user do
        block.call
      end
    end
  end

  def puma_user(role)
    properties = role.properties
    properties.fetch(:puma_user) || # local property for puma only
      fetch(:puma_user) ||
      properties.fetch(:run_as) || # global property across multiple capistrano gems
      role.user
  end

  def template_puma(role)
    templates_path(role).each do |path|
      if File.file? path
        erb = File.read path
        upload! StringIO.new(ERB.new(erb).result(binding)), fetch(:puma_conf)
        break
      else
        next
      end
    end
  end

  def templates_path(role)
    [
      "config/deploy/templates/puma-#{fetch(:stage)}-#{role.hostname}.rb.erb",
      "config/deploy/templates/puma-#{role.hostname}.rb.erb",
      "config/deploy/templates/puma-#{fetch(:stage)}.rb.erb",
      "config/deploy/templates/puma.rb.erb",
      "lib/capistrano/templates/puma-#{fetch(:stage)}-#{role.hostname}.rb.erb",
      "lib/capistrano/templates/puma-#{role.hostname}.rb.erb",
      "lib/capistrano/templates/puma-#{fetch(:stage)}.rb.erb",
      "lib/capistrano/templates/puma.rb.erb",
      File.expand_path("../../templates/puma.rb.erb", __FILE__)
    ]
  end
end
