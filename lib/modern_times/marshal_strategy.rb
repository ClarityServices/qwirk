require 'modern_times/marshal_strategy/bson'
require 'modern_times/marshal_strategy/json'
require 'modern_times/marshal_strategy/ruby'
require 'modern_times/marshal_strategy/string'
require 'modern_times/marshal_strategy/yaml'

# Defines some default marshaling strategies for use in marshaling/unmarshaling objects
# written and read via jms.  Implementing classes must define the following methods:
#
#   # Return symbol
#   #  :text  if session.create_text_message should be used to generate the JMS message
#   #  :bytes if session.create_bytes_message should be used to generate the JMS message
#   def marshal_type
#     # Return either :text or :bytes
#     :text
#   end
#
#   # Defines the conversion to wire format by the publisher of the message
#   def marshal(object)
#     # Operate on object and convert to message format
#   end
#
#   # Defines the conversion from wire format by the consumer of the message
#   def unmarshal(msg)
#     # Operate on message to convert it from wire protocol back to object format
#   end

module ModernTimes
  module MarshalStrategy
    @options = {
        :ruby   => Ruby,
        :string => String,
        :json   => JSON,
        :bson   => BSON,
        :yaml   => YAML,
    }

    def self.find(marshaler)
      if marshaler.nil?
        return Ruby
      elsif marshaler.kind_of? Symbol
        val = @options[marshaler]
        return val if val
      elsif valid?(marshaler)
        return marshaler
      end
      raise "Invalid marshal strategy: #{marshaler}"
    end

    # Allow user-defined marshal strategies
    def self.register(hash)
      hash.each do |key, marshaler|
        raise "Invalid marshal strategy: #{marshaler}" unless valid?(marshaler)
        @options[key] = marshaler
      end
    end

    def self.unregister(sym)
      @options.delete(sym)
    end

    def self.valid?(marshaler)
      return marshaler.respond_to?(:marshal_type) &&
          marshaler.respond_to?(:marshal) &&
          marshaler.respond_to?(:unmarshal)
    end
  end
end
