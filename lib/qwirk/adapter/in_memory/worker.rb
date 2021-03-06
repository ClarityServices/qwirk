# Handle Messaging and Queuing using JMS
module Qwirk
  module Adapter
    module InMemory
      class Worker
        attr_reader :stopped

        def initialize(name, marshaler, queue)
          @name       = name
          @marshaler  = marshaler
          @queue      = queue
        end

        def receive_message
          message, @reply_queue = @queue.read(self)
          return message
        end

        def acknowledge_message(message)
        end

        def send_response(original_message, marshaled_object)
          # We unmarshal so our workers get consistent messages regardless of the adapter
          do_send_response(original_message, @marshaler.unmarshal(marshaled_object))
        end

        def send_exception(original_message, e)
          # TODO: I think exceptions should be recreated fully so no need for marshal/unmarshal?
          do_send_response(original_message, Qwirk::RemoteException.new(e))
        end

        def message_to_object(msg)
          # The publisher has already unmarshaled the object to save hassle here.
          return msg
        end

        def handle_failure(message, exception, fail_queue_name)
          # TODO: Mode for persisting to flat file?
          Qwirk.logger.warn("Dropping message that failed: #{message}")
        end

        def stop
          return if @stopped
          @stopped = true
          Qwirk.logger.debug { "Stopping #{self}" }
          @queue.interrupt_read
        end

        # If the worker_config has been commanded to stop, workers will continue processing messages until this returns true
        def ready_to_stop?
          @queue.stopped?
        end

        def to_s
          "#{@name} (InMemory)"
        end

        ## End of required override methods for worker impl
        private

        def do_send_response(original_message, object)
          Qwirk.logger.debug { "Returning #{object} to queue #{@reply_queue}" }
          return unless @reply_queue
          @reply_queue.write([original_message.object_id, object, @name])
          return true
        end
      end
    end
  end
end
