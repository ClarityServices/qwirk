require 'benchmark'

module ModernTimes
  module JMS
  
    # Base Worker Class for any class that will be processing messages from topics or queues
    # By default, it will consume messages from a queue with the class name minus the Worker postfix.
    # For example, the queue call is unnecessary as it will default to a value of 'Foo' anyways:
    #  class FooWorker < ModernTimes::JMS::Worker
    #    queue 'Foo'
    #    def perform(obj)
    #      # Perform work on obj
    #    end
    #  end
    #
    # A topic can be specified using virtual_topic as follows (ActiveMQ only).  Multiple separate workers can
    # subscribe to the same topic (under ActiveMQ - see http://activemq.apache.org/virtual-destinations.html):
    #  class FooWorker < ModernTimes::JMS::Worker
    #    virtual_topic 'Zulu'
    #    def perform(obj)
    #      # Perform work on obj
    #    end
    #  end
    #
    # Filters can also be specified within the class:
    #  class FooWorker < ModernTimes::JMS::Worker
    #    filter 'age > 30'
    #    def perform(obj)
    #      # Perform work on obj
    #    end
    #  end
    #
    #
    module Worker
      include ModernTimes::Base::Worker

      attr_reader :session, :error_count, :time_track, :destination_options
      attr_accessor :message

      module ClassMethods
        def create_supervisor(manager, worker_options)
          Supervisor.new(manager, self, {}, worker_options)
        end

        def virtual_topic(name, opts={})
          # ActiveMQ only
          dest_options[:virtual_topic_name] = name.to_s
        end

        def queue(name, opts={})
          dest_options[:queue_name] = name.to_s
        end

        def dest_options
          @dest_options ||= {}
        end

        # Set the fail_queue
        # target =>
        #   boolean
        #     true - exceptions in the worker will cause the message to be forwarded to the queue of <default-name>Fail
        #       For instance, an Exception in FooWorker#perform will forward the message to the queue FooFail
        #     false - exceptions will not result in the message being forwarded to a fail queue
        #   string - equivalent to true but the string defines the name of the fail queue
        def fail_queue(target, opts={})
          @fail_queue_target = name
        end

        def fail_queue_target
          # Don't overwrite if the user set to false, only if it was never set
          @fail_queue_target
        end

        # Defines the default value of the fail_queue_target.  For extenders of this class, the default will be true
        # but extenders can change this (RequestWorker returns exceptions to the caller so it defaults to false).
        def default_fail_queue_target
          true
        end
      end

      def self.included(base)
        base.extend(ModernTimes::Base::Worker::ClassMethods)
        base.extend(ClassMethods)
      end

      def initialize(opts={})
        super
        @stopped       = false
        @status        = 'initialized'
        @time_track    = ModernTimes::TimeTrack.new
        @error_count   = 0
        @message_mutex = Mutex.new

        @destination_options = self.class.dest_options.dup
        # Default the queue name to the Worker name if a destinations hasn't been specified
        if @destination_options.keys.select {|k| [:virtual_topic_name, :queue_name, :destination].include?(k)}.empty?
          @destination_options[:queue_name] = self.name
        end

        @real_destination_options = @destination_options.dup
        virtual_topic_name = @real_destination_options.delete(:virtual_topic_name)
        @real_destination_options[:queue_name] = "Consumer.#{name}.VirtualTopic.#{virtual_topic_name}" if virtual_topic_name

        target = opts[:fail_queue]
        target = self.class.fail_queue_target if target.nil?
        target = self.class.default_fail_queue_target if target.nil?
        if target == true
          @fail_queue_name = "#{name}Fail"
        elsif target == false
          @fail_queue_name = nil
        elsif target.kind_of?(String)
          @fail_queue_name = target
        else
          raise "Invalid fail queue: #{target}"
        end
      end

      def message_count
        @time_track.total_count
      end

      def status
        @status || "Processing message #{@time_track.total_count}"
      end

      # Start the event loop for handling messages off the queue
      def start
        @session = Connection.create_session
        @consumer = @session.consumer(@real_destination_options)
        @session.start

        ModernTimes.logger.debug "#{self}: Starting receive loop"
        @status = nil
        while !@stopped && msg = @consumer.receive
          @time_track.perform do
            @message_mutex.synchronize do
              on_message(msg)
              msg.acknowledge
            end
          end
          ModernTimes.logger.info {"#{self}::on_message (#{('%.1f' % (@time_track.last_time*1000.0))}ms)"} if ModernTimes::JMS::Connection.log_times?
          ModernTimes.logger.flush if ModernTimes.logger.respond_to?(:flush)
        end
        @status = 'Exited'
        ModernTimes.logger.info "#{self}: Exiting"
      rescue Exception => e
        @status = "Exited with exception #{e.message}"
        ModernTimes.logger.error "#{self}: Exception, thread terminating: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
      ensure
        ModernTimes.logger.flush if ModernTimes.logger.respond_to?(:flush)
      end

      def stop
        @stopped = true
        # Don't clobber the session before a reply
        @message_mutex.synchronize do
          @consumer.close if @consumer
          @session.close if @session
        end
      end

      def perform(object)
        raise "#{self}: Need to override perform method in #{self.class.name} in order to act on #{object}"
      end

      def to_s
        "#{@real_destination_options.to_a.join('=>')}:#{index}"
      end

      def log_backtrace(e)
        ModernTimes.logger.error "\t#{e.backtrace.join("\n\t")}"
      end

      #########
      protected
      #########

      def fail_queue_name
        @fail_queue_name
      end

      def on_message(message)
        @message = message
        marshaler = ModernTimes::MarshalStrategy.find(message['mt:marshal'] || :ruby)
        object = marshaler.unmarshal(message.data)
        ModernTimes.logger.debug {"#{self}: Received Object: #{object}"}
        perform(object)
      rescue Exception => e
        on_exception(e)
      ensure
        ModernTimes.logger.debug {"#{self}: Finished processing message"}
      end

      def increment_error_count
        @error_count += 1
      end

      def on_exception(e)
        increment_error_count
        ModernTimes.logger.error "#{self}: Messaging Exception: #{e.message}"
        log_backtrace(e)
        if fail_queue_name
          session.producer(:queue_name => fail_queue_name) do |producer|
            # TODO: Can't add attribute to read-only message?
            #message['mt:exception'] = ModernTimes::RemoteException.new(e).to_hash.to_yaml
            producer.send(message)
          end
        end
      rescue Exception => e
        ModernTimes.logger.error "#{self}: Exception in exception reply: #{e.message}"
        log_backtrace(e)
      end
    end
  end
end
