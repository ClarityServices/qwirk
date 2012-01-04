require 'yaml'

require 'qwirk/queue_adapter/jms/connection'
require 'qwirk/queue_adapter/jms/publisher'
require 'qwirk/queue_adapter/jms/active_mq_publisher'
require 'qwirk/queue_adapter/jms/worker_config'
require 'qwirk/queue_adapter/jms/worker'
require 'qwirk/queue_adapter/jms/active_mq_worker'

module Qwirk
  module JMS
    def self.same_destination?(options1, options2)
      if options1[:queue_name]
        return options1[:queue_name]  == options2[:queue_name]
      elsif options1[:topic_name]
        return options1[:topic_name]  == options2[:topic_name]
      elsif options1[:virtual_topic_name]
        return options1[:virtual_topic_name]  == options2[:virtual_topic_name]
      elsif options1[:destination]
        return options1[:destination] == options2[:destination]
      else
        return false
      end
    end

    def self.create_message(session, marshaled_object, marshal_type)
      case marshal_type
        when :text
          session.create_text_message(marshaled_object)
        when :bytes
          msg = session.create_bytes_message()
          msg.data = marshaled_object
          msg
        else raise "Invalid marshal type: #{marshal_type}"
      end
    end

    def self.parse_response(message)
      if error_yaml = message['mt:exception']
        return Qwirk::RemoteException.from_hash(YAML.load(error_yaml))
      end
      marshaler = Qwirk::MarshalStrategy.find(message['mt:marshal'] || :ruby)
      return marshaler.unmarshal(message.data)
    end
  end
end