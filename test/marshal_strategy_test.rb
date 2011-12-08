require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'modern_times'

class Klass
  def initialize(str)
    @str = str
  end
  def hello
    @str
  end
end

module SpockMarshalStrategy
  def self.marshal_type
    :text
  end

  # Change days to hours
  def self.marshal(i)
    (i.to_i * 24).to_s
  end

  # Change hours to days
  def self.unmarshal(str)
    str.to_i / 24
  end
end

class MarshalStrategyTest < Test::Unit::TestCase
  context '' do
    setup do
      ModernTimes::MarshalStrategy.register(:spock => SpockMarshalStrategy)

      @bson   = ModernTimes::MarshalStrategy.find(:bson)
      @json   = ModernTimes::MarshalStrategy.find(:json)
      @ruby   = ModernTimes::MarshalStrategy.find(:ruby)
      @string = ModernTimes::MarshalStrategy.find(:string)
      @yaml   = ModernTimes::MarshalStrategy.find(:yaml)
      @spock  = ModernTimes::MarshalStrategy.find(:spock)
    end

    should 'marshal and unmarshal correctly' do
      hash = {'foo' => 42, 'bar' => 'zulu'}
      str  = 'abcdef1234'
      obj  = Klass.new('hello')
      i    = 6
      assert_equal hash, @bson.unmarshal(@bson.marshal(hash))
      assert_equal hash, @json.unmarshal(@json.marshal(hash))
      assert_equal hash, @ruby.unmarshal(@ruby.marshal(hash))
      assert_equal hash, @yaml.unmarshal(@yaml.marshal(hash))
      assert_equal str,  @string.unmarshal(@string.marshal(str))
      assert_equal obj.hello,  @ruby.unmarshal(@ruby.marshal(obj)).hello
      assert_equal i, @spock.unmarshal(@spock.marshal(i))
    end
  end
end
