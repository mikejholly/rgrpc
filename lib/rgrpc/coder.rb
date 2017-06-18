# frozen_string_literal: true

module RGRPC
  # Simple class to wrap multiple coders
  class Coder
    def initialize(encoder, decoder)
      @encoder = encoder
      @decoder = decoder
    end

    def encode(unpacked)
      @encoder.encode(unpacked)
    end

    def decode(packed)
      @decoder.decode(packed)
    end
  end
end
