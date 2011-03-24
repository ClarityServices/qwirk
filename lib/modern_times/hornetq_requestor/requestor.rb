module ModernTimes
  module HornetQRequestor
    class Requestor < ModernTimes::HornetQ::Publisher
      attr_reader :reply_queue

      def initialize(address, options={})
        super
        @reply_queue = "#{address}.#{Java::java.util::UUID.randomUUID.toString}"
        @reply_queue_simple = Java::org.hornetq.api.core.SimpleString.new(@reply_queue)
        ModernTimes::HornetQ::Client.session_pool.session do |session|
          session.create_temporary_queue(@reply_queue, @reply_queue)
        end
      end
      
      def request(object, timeout)
        start = Time.now
        message_id = Java::org.hornetq.utils.UUIDGenerator.instance.generateUUID.toString
        publish(object,
                nil,
                MESSAGE_ID => message_id,
                Java::OrgHornetqCoreClientImpl::ClientMessageImpl::REPLYTO_HEADER_NAME => @reply_queue_simple)
                #HornetQMessage.CORRELATIONID_HEADER_NAME
                #REPLY_QUEUE => @reply_queue,
                #MESSAGE_ID  => message_id)
        return RequestHandle.new(self, message_id, start, timeout)
      end

      # For non-configured Rails projects, The above request method will be overridden to
      # call this request method instead which calls all the HornetQ workers that
      # operate on the given address.
      def dummy_request(object)
        @@worker_instances.each do |worker|
          if worker.kind_of?(Worker) && worker.address_name == address
            ModernTimes.logger.debug "Dummy requesting #{object} to #{worker}"
            return new OpenStruct(:read_response => worker.request(object))
          end
        end
        raise "No worker to handle #{address} request of #{object}"
      end

      def self.setup_dummy_requesting(workers)
        @@worker_instances = workers.map {|worker| worker.new}
        alias_method :real_request, :request
        alias_method :request, :dummy_request
      end
    end
  end
end
