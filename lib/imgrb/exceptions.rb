module Imgrb
  ##
  #Image specific exceptions
  #(Remove some/all?)
  module Exceptions

    class ChunkError < StandardError
    end

    class CrcError < StandardError
    end

    class HeaderError < StandardError
    end

    class ImageError < StandardError
    end

    class AnimationError < StandardError
    end

  end
end
