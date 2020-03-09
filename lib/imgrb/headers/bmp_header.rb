module Imgrb::Headers
  ##
  #This class represents a BMP header. If the loaded image is a BMP image, then
  #the image instance contains an instance of this class.
  class BmpHeader < MinimalHeader
    attr_reader :horizontal_res, :vertical_res, :important_colors,
                :color_planes, :data_offset
    def initialize(width, height, bit_depth, compression_method, image_type,
                   color_planes, horizontal_res = 0, vertical_res = 0,
                   palette = [], important_colors = [], data_offset = 54)

      super(width, height, bit_depth, compression_method, image_type)
      @color_planes = color_planes
      @horizontal_res = horizontal_res
      @vertical_res = vertical_res
      @palette = palette
      @important_colors = important_colors
      @data_offset = data_offset
      check_bmp_header_error

    end

    def image_format
      :bmp
    end

    ##
    #Returns a string containing the header bytes for a bmp header
    #with a dib header of size 40, i.e. a "BITMAPINFOHEADER".
    def print_header
      header = ""
      Imgrb::BmpMethods::add_bmp_bytes(header, file_size, 4)

      #Reserved, depends on application. Safe to set to 0s
      header << 0.chr*4

      #Offset. 40 (from DIB) + 14 (from header)
      Imgrb::BmpMethods::add_bmp_bytes(header, 54, 4)

      #Size of DIB-header
      Imgrb::BmpMethods::add_bmp_bytes(header, 40, 4)

      Imgrb::BmpMethods::add_bmp_bytes(header, @width, 4)
      Imgrb::BmpMethods::add_bmp_bytes(header, @height, 4)

      #Color planes, must be set to 1
      Imgrb::BmpMethods::add_bmp_bytes(header, 1, 2)

      #Bits per pixel. Always write 24-bit bmps.
      Imgrb::BmpMethods::add_bmp_bytes(header, 24, 2)

      #No compression
      Imgrb::BmpMethods::add_bmp_bytes(header, 0, 4)

      #Image size. Can be 0 for compression method 0.
      Imgrb::BmpMethods::add_bmp_bytes(header, image_size, 4)

      Imgrb::BmpMethods::add_bmp_bytes(header, @horizontal_res, 4)
      Imgrb::BmpMethods::add_bmp_bytes(header, @vertical_res, 4)

      #Default color palette
      Imgrb::BmpMethods::add_bmp_bytes(header, 0, 4)

      #All colors important
      Imgrb::BmpMethods::add_bmp_bytes(header, 0, 4)
    end

    ##
    #Returns DIB type
    def dib_type
      case @image_type
      when 12 then "BITMAPCOREHEADER/OS21XBITMAPHEADER"
      when 40 then "BITMAPINFOHEADER"
      when 52 then "BITMAPV2INFOHEADER"
      when 56 then "BITMAPV3INFOHEADER"
      when 64 then "BITMAPCOREHEADER2/OS22XBITMAPHEADER"
      when 108 then "BITMAPV4HEADER"
      when 124 then "BITMAPV5HEADER"
      else "UNKNOWN" end
    end

    def colors
      if @palette == []
        2**@bit_depth
      else
        @palette.size
      end
    end

    def paletted?
      false
    end

    ##
    #Number of channels
    def channels
      3
    end

    def has_alpha?
      false
    end

    ##
    #Returns corresponding PngHeader
    def to_png_header
      PngHeader.new(@width, @height, 8, 0, 2, 0, 0)
    end

    def file_size
      file_size = 14 #Size reserved for header
      file_size += 40 #Size reserved for DIB header.
      file_size += image_size #Size of image bytes
    end

    def image_size
      padded_width = Imgrb::BmpMethods::find_multiple_of_4(@width*channels)
      padded_width * @height
    end

    private

    def valid_bit_depth?
      @bit_depth == 24
    end

    def check_bmp_header_error
      if !valid_bit_depth?
        raise Imgrb::Exceptions::HeaderError, "Unsupported bit depth: "\
                                              "#{@bit_depth} for a bmp image."
      end

      if @compression_method != 0
        raise Imgrb::Exceptions::HeaderError, "Bmp compression not supported, "\
                                              "found compression method: "\
                                              "#{@compression_method}"
      end

      if @image_type != 40
        raise Imgrb::Exceptions::HeaderError, "Unsupported DIB header: "\
                                              "#{dib_type}"
      end
    end

  end
end
