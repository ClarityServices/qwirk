require '../setup'
require './foo_worker'
require './publisher'
require './task'

# If we're not starting up a standalone publisher, then start up a manager
if ENV['RACK_ENV'] != 'publisher'
  manager = Qwirk::Manager.new($adapter, :name => 'Worker', :persist_file => 'qwirk_persist.yml')
  at_exit { manager.stop }
end
if ENV['RACK_ENV'] != 'worker'
  Rumx::Bean.root.bean_add_child(:Publisher, Publisher.new($adapter))
end
run Rumx::Server