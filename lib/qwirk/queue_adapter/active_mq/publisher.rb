module Qwirk
  module QueueAdapter
    module ActiveMQ
      class Publisher < JMS::Publisher
        def initialize(queue_name, topic_name, options)
          topic_name = "VirtualTopic.#{topic_name}" if topic_name
          super(queue_name, topic_name, options)
        end
      end
    end
  end
end