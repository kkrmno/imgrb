module Imgrb::Headers
  ##
  #This class represents a PNG header, the IHDR chunk essentially, but there
  #is also a class that represents the chunk. The difference is that the chunk
  #class is minimal and used while loading the (PNG) image
  #
  #If the loaded image is a PNG image (not APNG), then the image instance contains an
  #instance of this class.
  class PngHeader < MinimalHeader
    attr_reader :filter_method, :interlace_method
    def initialize(width, height, bit_depth, compression_method, image_type,
                   filter_method, interlace_method)

      super(width, height, bit_depth, compression_method, image_type)
      @filter_method = filter_method
      @interlace_method = interlace_method
      @critical_changes_made = false
      check_IHDR_error
    end

    def image_format
      :png
    end

    ##
    #Number of bytes per bitmap row (excludes filter byte)
    def bytes_per_row
      width * bit_depth / 8
    end

    ##
    #Should be called if critical changes are made (i.e. affecting pixel data).
    #This should be considered when copying over unsafe ancillary chunks.
    def making_critical_changes!
      @critical_changes_made = true
    end

    ##
    #If critical changes have been made, unsafe-to-copy ancillary chunks must
    #be given special care.
    def critical_changes_made?
      @critical_changes_made
    end

    ##
    #Convert to another color type
    def to_color_type(new_col_type, bitmap)
      rows = bitmap.rows
      @critical_changes_made = true unless new_col_type == @image_type
      if @image_type == Imgrb::PngConst::INDEXED &&
         (new_col_type == Imgrb::PngConst::TRUECOLOR ||
          new_col_type == Imgrb::PngConst::TRUECOLOR_ALPHA)

        if bitmap.has_alpha?
          unless width*4*height == rows.size*rows[0].size
            raise Imgrb::Exceptions::HeaderError,
                  "Conversion to #{color_type(new_col_type)} failed"
          end
        else
          unless width*3*height == rows.size*rows[0].size
            raise Imgrb::Exceptions::HeaderError,
                  "Conversion to #{color_type(new_col_type)} failed"
          end
        end

        @bit_depth = 8 #Png palette must be 8-bit.
        @image_type = new_col_type

      elsif @image_type == Imgrb::PngConst::GRAYSCALE &&
            new_col_type == Imgrb::PngConst::GRAYSCALE_ALPHA

        unless width*2*height == rows.size*rows[0].size
            raise Imgrb::Exceptions::HeaderError,
                  "Conversion to #{color_type(new_col_type)} failed"
        end

        @image_type = new_col_type

      elsif @image_type == Imgrb::PngConst::TRUECOLOR &&
            new_col_type == Imgrb::PngConst::TRUECOLOR_ALPHA

        unless width*4*height == rows.size*rows[0].size
            raise Imgrb::Exceptions::HeaderError,
                  "Conversion to #{color_type(new_col_type)} failed"
        end

        @image_type = new_col_type

      elsif @image_type == Imgrb::PngConst::TRUECOLOR_ALPHA &&
            new_col_type == Imgrb::PngConst::TRUECOLOR

        unless width*3*height == rows.size*rows[0].size
            raise Imgrb::Exceptions::HeaderError,
                  "Conversion to #{color_type(new_col_type)} failed"
        end

        @image_type = new_col_type

      elsif @image_type == Imgrb::PngConst::GRAYSCALE_ALPHA &&
            new_col_type == Imgrb::PngConst::GRAYSCALE

        unless width*height == rows.size*rows[0].size
            raise Imgrb::Exceptions::HeaderError,
                  "Conversion to #{color_type(new_col_type)} failed"
        end

        @image_type = new_col_type
      else
        unless width*Imgrb::PngMethods.channels(new_col_type)*height == rows.size*rows[0].size
          raise Imgrb::Exceptions::HeaderError, "Dimensions did not match when "\
                                                "trying to convert from "\
                                                "#{color_type} to "\
                                                "#{color_type(new_col_type)}."
        end
        @image_type = new_col_type
      end
    end

    def interlaced?
      return @interlace_method != Imgrb::PngConst::NOT_INTERLACED
    end

    def grayscale?
      return (@image_type == Imgrb::PngConst::GRAYSCALE ||
              @image_type == Imgrb::PngConst::GRAYSCALE_ALPHA)
    end

    def color_type(image_type = @image_type)
      case image_type
      when Imgrb::PngConst::GRAYSCALE       then "grayscale"
      when Imgrb::PngConst::TRUECOLOR       then "truecolor"
      when Imgrb::PngConst::INDEXED         then "indexed-color"
      when Imgrb::PngConst::GRAYSCALE_ALPHA then "grayscale with alpha"
      when Imgrb::PngConst::TRUECOLOR_ALPHA then "truecolor with alpha"
      else "INVALID" end
    end

    ##
    #Check if the header has a valid color type
    def valid_color_type?
      @image_type == Imgrb::PngConst::GRAYSCALE       ||
      @image_type == Imgrb::PngConst::TRUECOLOR       ||
      @image_type == Imgrb::PngConst::INDEXED         ||
      @image_type == Imgrb::PngConst::GRAYSCALE_ALPHA ||
      @image_type == Imgrb::PngConst::TRUECOLOR_ALPHA
    end

    def paletted?
      @image_type == Imgrb::PngConst::INDEXED
    end

    ##
    #Returns number of channels
    def channels
      Imgrb::PngMethods::channels(@image_type)
    end

    def has_alpha?
      @image_type == Imgrb::PngConst::TRUECOLOR_ALPHA ||
      @image_type == Imgrb::PngConst::GRAYSCALE_ALPHA
    end

    ##
    #Returns a string containing a png IHDR block.
    def print_header(type = @image_type, bit_depth = 8)
      #bit_depth = 8 #Default bit depth
      compression = 0
      filter = 0
      interlace = Imgrb::PngConst::NOT_INTERLACED
      chunk = [@width, @height, bit_depth, type,
               compression, filter, interlace]
      #Pack into 17 bytes long header, 13 for data + 4 bytes for "IHDR")
      chunk = chunk.pack('NNCCCCC')
      #Calculate crc for IHDR chunk
      crc = [Zlib.crc32("IHDR" + chunk, 0)].pack('N')
            #Size of header                            IHDR data
      return "\x00\x00\x00\x0D" << "IHDR" << chunk << crc
    end

    ##
    #Returns a BmpHeader
    def to_bmp_header
      BmpHeader.new(@width, @height, 24, 0, 40, 1)
    end

    ##
    #Returns an ApngHeader
    def to_apng_header(number_of_frames = -1, number_of_plays = -1, default_image = nil)
      ApngHeader.new(@width, @height, @bit_depth, @compression_method, @image_type,
                    @filter_method, @interlace_method, number_of_frames, number_of_plays,
                    default_image)
    end

    private

    def valid_bit_depth?
      if @image_type == Imgrb::PngConst::GRAYSCALE
        return (@bit_depth == 1 || @bit_depth == 2 ||
            @bit_depth == 4 || @bit_depth == 8 || @bit_depth == 16)
      elsif @image_type == Imgrb::PngConst::TRUECOLOR
        return (@bit_depth == 8 || @bit_depth == 16)
      elsif @image_type == Imgrb::PngConst::INDEXED
        return (@bit_depth == 1 || @bit_depth == 2 ||
            @bit_depth == 4 || @bit_depth == 8)
      elsif @image_type == Imgrb::PngConst::GRAYSCALE_ALPHA
        return (@bit_depth == 8 || @bit_depth == 16)
      elsif @image_type == Imgrb::PngConst::TRUECOLOR_ALPHA
        return (@bit_depth == 8 || @bit_depth == 16)
      else
        return false
      end
    end

    def check_IHDR_error
      if !valid_color_type?
        raise Imgrb::Exceptions::HeaderError, "Invalid color type "\
                                              "#{@image_type}"
      elsif !valid_bit_depth?
        raise Imgrb::Exceptions::HeaderError, "Invalid bit depth: "\
                                              "#{@bit_depth}, "\
                                              "for color type: #{color_type}"
      elsif @width <= 0 || @height <= 0
        raise Imgrb::Exceptions::HeaderError, "Width and height must be "\
                                              "greater than 0"
      elsif @filter_method != 0
        raise Imgrb::Exceptions::HeaderError, "Filter method has to be 0"
      elsif @interlace_method != Imgrb::PngConst::NOT_INTERLACED &&
            @interlace_method != Imgrb::PngConst::ADAM7
        raise Imgrb::Exceptions::HeaderError, "Interlace method has to be "\
                                              "0 or 1"
      elsif @compression_method != 0
        raise Imgrb::Exceptions::HeaderError, "Unknown compression method: "\
                                              "#{@compression_method}"
      end
    end


  end
end
