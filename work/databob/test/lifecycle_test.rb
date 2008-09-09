# require File.dirname(__FILE__) + '/../dev-utils/eval_debugger'
require 'abstract_unit'
require 'fixtures/topic'

class Topic
  def after_find
  end
end

class TopicManualObserver
  include Singleton

  attr_reader :action, :object, :callbacks

  def initialize
    Topic.add_observer(self)
    @callbacks = []
  end

  def update(callback_method, object)
    @callbacks << { "callback_method" => callback_method, "object" => object }
  end

  def has_been_notified?
    !@callbacks.empty?
  end
end

class TopicaObserver < ActiveRecord::Observer
  def self.observed_class() Topic end
  
  attr_reader :topic
  
  def after_find(topic)
    @topic = topic
  end
end

class TopicObserver < ActiveRecord::Observer
  attr_reader :topic
  
  def after_find(topic)
    @topic = topic
  end
end

class LifecycleTest < Test::Unit::TestCase
  def setup
    @topic_fixtures = create_fixtures("topics")
  end

  def test_before_destroy
    assert_equal 2, Topic.count
    Topic.find(1).destroy
    assert_equal 0, Topic.count
  end
  
  def test_after_save
    topic_observer = TopicManualObserver.instance

    topic = Topic.find(1)
    topic.title = "hello"
    topic.save
    
    assert topic_observer.has_been_notified?
    assert_equal :after_save, topic_observer.callbacks.last["callback_method"]
  end
  
  def test_observer_update_on_save
    topic_observer = TopicManualObserver.instance

    topic = Topic.find(1)    
    assert topic_observer.has_been_notified?
    assert_equal :after_find, topic_observer.callbacks.first["callback_method"]
  end
  
  def test_auto_observer
    topic_observer = TopicaObserver.instance

    topic = Topic.find(1)    
    assert_equal topic_observer.topic.title, topic.title
  end
  
  def test_infered_auto_observer
    topic_observer = TopicObserver.instance

    topic = Topic.find(1)    
    assert_equal topic_observer.topic.title, topic.title
  end
end