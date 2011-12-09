require 'timeout'

module Qwirk
  class PublishHandle
    def initialize(publisher, message_id, start)
      @publisher  = publisher
      @message_id = message_id
      @start      = start
    end

    # Waits the given timeout for a response message on the queue.
    #
    # If called w/o a block:
    #   Returns the message
    #   Returns nil on timeout
    #   Raises RemoteException on a remote exception
    #
    # If called with a block, for instance:
    #   handle.read_response(timeout) do |response|
    #     response.on_message 'CharCount' do |hash|
    #       puts "CharCount returned #{hash.inspect}"
    #     end
    #     response.on_message 'Length', 'Reverse' do |val|
    #       puts "#{response.name} returned #{val}"
    #     end
    #     response.on_message 'ExceptionRaiser' do |val|
    #       puts "#{response.name} didn't raise an exception but returned #{val}"
    #     end
    #     response.on_timeout 'Reverse' do
    #       puts "Reverse has it's own timeout handler"
    #     end
    #     response.on_timeout do
    #       puts "#{response.name} did not respond in time"
    #     end
    #     response.on_remote_exception 'ExceptionRaiser' do
    #       puts "It figures that ExceptionRaiser would raise an exception"
    #     end
    #     response.on_remote_exception do |e|
    #       puts "#{response.name} raised an exception #{e.message}\n\t#{e.backtrace.join("\n\t")}"
    #     end
    #   end
    #
    # The specified blocks will be called for each response.  For instance, LengthWorker#request
    # might return 4 and "Length returned 4" would be displayed.  If it failed to respond within the
    # timeout, then "Length did no respond in time" would be displayed.
    # For Workers that raise an exception, they will either be handled by their specific handler if it exists or
    # the default exception handler.  If that doesn't exist either, then the RemoteException will be raised for the
    # whole read_response call.  Timeouts will also be handled by the default timeout handler unless a specific one
    # is specified.  All messages must have a specific handler specified because the call won't return until all
    # specified handlers either return, timeout, or return an exception.
    #
    def read_response(timeout, &block)
      raise "Invalid call to read_response for #{@publisher}, not setup for responding" unless @publisher.response_options
      @publisher.adapter.with_response(message_id) do |consumer|
        if block_given?
          return read_multiple_response(consumer, timeout, &block)
        else
          response = read_single_response(consumer, timeout)
          raise response if response.kind_of?(Qwirk::RemoteException)
          return response
        end
      end
    end

    #######
    private
    #######

    def read_single_response(consumer, timeout)
      leftover_timeout = @start + timeout - Time.now
      response, @worker_name = consumer.read_response(leftover_timeout)
      return response
    end

    def read_multiple_response(consumer, timeout, &block)
      worker_response = WorkerResponse.new(@start)
      yield worker_response

      until worker_response.done? do
        response = read_single_response(consumer, timeout)
        if !response
          worker_response.make_timeout_calls
          return
        end
        if response.kind_of?(Qwirk::RemoteException)
          worker_response.make_exception_call(@worker_name, response)
        else
          worker_response.make_message_call(@worker_name, response)
        end
      end
    end

    class WorkerResponse
      attr_reader :name, :start

      def initialize(start)
        @start                   = start
        @message_hash            = {}
        @timeout_hash            = {}
        @exception_hash          = {}
        @default_timeout_block   = nil
        @default_exception_block = nil
        @done_array              = []
      end

      # Msecs since publish
      def msec_delta
        (Time.now - @start) * 1000
      end

      def on_message(*names, &block)
        raise 'Must explicitly define all message handlers so we know that we\'re done' if names.empty?
        names.each {|name| @message_hash[name] = block}
      end

      def on_timeout(*names, &block)
        if names.empty?
          @default_timeout_block = block
        else
          names.each {|name| @timeout_hash[name] = block}
        end
      end

      def on_remote_exception(*names, &block)
        if names.empty?
          @default_exception_block = block
        else
          names.each {|name| @exception_hash[name] = block}
        end
        @remote_exception_block = block
      end

      def make_message_call(name, obj)
        # Give the client access to the name
        @name = name
        block = @message_hash[name]
        block.call(obj) if block
        @done_array << name
      end

      def done?
        (@message_hash.keys - @done_array).empty?
      end

      def make_timeout_calls
        @timeouts = @message_hash.keys - @done_array
        @timeouts.each do |name|
          # Give the client access to the name
          @name = name
          block = @timeout_hash[name] || @default_timeout_block
          block.call if block
        end
      end

      def make_exception_call(name, e)
        @name = name
        block = @exception_hash[name] || @default_exception_block
        if block
          block.call(e)
          @done_array << name
        else
          raise e
        end
      end
    end
  end
end
