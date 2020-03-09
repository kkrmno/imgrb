module Imgrb
  ##
  #This module contains headers for different image formats (including
  #internally used headers)
  module Headers

    ##
    #This class is used internally as a generic header. If a new image
    #is created from scratch, rather than loaded (e.g. a png image file),
    #then the image instance contains an instance of this class as the header.
    class ImgrbHeader < MinimalHeader

      def initialize(width, height, bit_depth = 8,
                     image_type = Imgrb::PngConst::TRUECOLOR)
        super(width, height, bit_depth, 0, image_type)
      end

      ##
      #Returns the number of channels
      def channels
        Imgrb::PngMethods::channels(@image_type)
      end

      def grayscale?
        @image_type == Imgrb::PngConst::GRAYSCALE_ALPHA ||
        @image_type == Imgrb::PngConst::GRAYSCALE
      end

      def has_alpha?
        @image_type == Imgrb::PngConst::TRUECOLOR_ALPHA ||
        @image_type == Imgrb::PngConst::GRAYSCALE_ALPHA
      end

      def paletted?
        @image_type == Imgrb::PngConst::INDEXED
      end

      def image_format
        :imgrb
      end

      ##
      #Returns corresponding bmp header
      def to_bmp_header
        BmpHeader.new(@width, @height, 24, 0, 40, 1)
      end

      ##
      #Returns corresponding png header
      def to_png_header
        PngHeader.new(@width, @height, @bit_depth, 0, @image_type, 0, 0)
      end

    end


  end
end
