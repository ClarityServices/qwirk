# Step 0
# Follow the directions for configuring jms.yml located in examples/README

# Step 1
# Start an ActiveMQ Server

# Step 2
# Start up the manager
rackup -p 4567

# Step 3
jruby publish.rb foobar 4 2

# Step 4
# Play around with the options in qwirk_persist.yml and repeat steps 2&3.
