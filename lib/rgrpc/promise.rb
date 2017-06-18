# frozen_string_literal: true

module RGRPC
  class Promise
    def initialize
      @val = nil
    end

    def value(timeout = nil)
      s = Time.now
      t = Thread.new do
        loop do
          if timeout
            break if Time.now - s > timeout
          end
          break if @val
        end
      end
      t.join
      @val
    end

    def set(v)
      @val = v
    end
  end
end
