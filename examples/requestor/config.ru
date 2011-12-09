# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'

require 'rubygems'
require 'erb'
require 'qwirk'
require 'yaml'
require 'reverse_echo_worker'

config = YAML.load(ERB.new(File.read(File.join(File.dirname(__FILE__), '..', 'jms.yml'))).result(binding))
Qwirk::JMS::Connection.init(config)

manager = Qwirk::Manager.new
manager.stop_on_signal(join=true)
manager['ReverseEcho'].count = 1
run Rumx::Server
