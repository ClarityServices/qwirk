require 'rubygems'
require 'modern_times/remote_exception'
require 'modern_times/marshal_strategy'
require 'modern_times/base_worker'
require 'modern_times/worker_config'
require 'modern_times/worker'
require 'modern_times/publisher'
require 'modern_times/publish_handle'
require 'modern_times/queue_adapter'
#require 'modern_times/batch'
require 'modern_times/manager'
require 'modern_times/loggable'
require 'modern_times/railsable'

module ModernTimes
  extend ModernTimes::Loggable
  extend ModernTimes::Railsable

  DEFAULT_NAME = 'ModernTimes'
end
