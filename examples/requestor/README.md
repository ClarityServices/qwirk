# Step 0
# Follow the directions for configuring jms.yml located in examples/README

# Step 1
# Start an ActiveMQ Server

# Step 2
# Start up the manager
rackup -p 4567

# Step 3
# Request 'my string' get reversed
jruby request.rb 'my string'
