module Imgrb::Headers
  ##
  #A minimal header. Provides basic functionality.
  #Other headers subclass this one.
  class MinimalHeader
    attr_reader :width, :height, :bit_depth, :compression_method, :image_type
    def initialize(width = 1, height = 1, bit_depth = -1,
                   compression_method = -1, image_type = -1)
      raise ArgumentError, "Image width must be at least 1" if width < 1
      raise ArgumentError, "Image height must be at least 1" if height < 1
      @width = width
      @height = height
      @bit_depth = bit_depth
      @compression_method = compression_method
      @image_type = image_type
    end

    def image_format
      :unknown
    end

    def animated?
      false
    end

    def grayscale?
      false
    end

    ##
    #FIXME: Should probably throw exception
    def to_png_header
      self
    end

    ##
    #FIXME: Should probably throw exception
    def to_bmp_header
      self
    end

    def resize(x, y, bitmap)
      @width = x
      @height = y
      bitmap.resize(x, y)
    end

    def number_of_frames
      0
    end
  end
end
