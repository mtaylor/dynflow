module Dynflow
  class Middleware::Stack

    def initialize(middleware_classes)
      unless middleware_classes.empty?
        top_class, *rest = middleware_classes
        @top  = top_class.new
        @rest = Middleware::Stack.new(rest)
      end
    end

    def evaluate(method, action, *args, &block)
      if action
        raise "Action doesn't respont to #{method}" unless action.respond_to?(method)
      end
      target = action || block
      raise ArgumentError, "neither action nor block specified" unless target
      original_thread_data = thread_data
      begin
        setup_thread_data(method, target)
        pass(*args)
      ensure
        self.thread_data = original_thread_data
      end
    end

    def pass(*args)
      raise "Middleware evaluation not setup" unless thread_data[:stack]
      original_stack = thread_data[:stack]
      begin
        thread_data[:stack] = @rest
        if top.is_a? Proc
          top.call(*args)
        elsif top.respond_to?(thread_data[:method])
          top.send(thread_data[:method], *args)
        else
          @rest.pass(*args)
        end
      ensure
        thread_data[:stack] = original_stack
      end
    end

    def top
      @top || thread_data[:target]
    end

    # There is no other way to share the data between middlewares then
    # through the thread when we don't want to recreate the stack at every call
    def setup_thread_data(method, target)
      self.thread_data = { method: method,
                           target: target,
                           stack: self }
    end

    def thread_data
      self.class.thread_data
    end

    def self.thread_data
      Thread.current[:dynflow_middleware]
    end

    def thread_data=(value)
      self.class.thread_data = value
    end

    def self.thread_data=(value)
      Thread.current[:dynflow_middleware] = value
    end
  end
end