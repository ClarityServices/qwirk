module Qwirk

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
  module MarshalStrategy

    @options = {}

    def self.find(marshaler)
      if marshaler.nil?
        return Ruby
      else
        val = @options[marshaler.to_sym]
        return val if val
      end
      raise "Invalid marshal strategy: #{marshaler}"
    end

    def self.registered?(marshaler)
      @options.has_key?(marshaler.to_sym)
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

require 'qwirk/marshal_strategy/bson'
require 'qwirk/marshal_strategy/json'
require 'qwirk/marshal_strategy/none'
require 'qwirk/marshal_strategy/ruby'
require 'qwirk/marshal_strategy/string'
require 'qwirk/marshal_strategy/yaml'
