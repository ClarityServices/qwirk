# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'

require 'rubygems'
require 'erb'
require 'modern_times'
require 'yaml'
require 'bar_worker'
require 'baz_worker'

config = YAML.load(ERB.new(File.read(File.join(File.dirname(__FILE__), '..', 'jms.yml'))).result(binding))
ModernTimes::JMS::Connection.init(config)

manager = ModernTimes::Manager.new(:persist_file => 'modern_times.yml')
manager.stop_on_signal
manager.allowed_workers = [BarWorker,BazWorker]
#manager.add(BarWorker, 2, {})
manager.join
