require 'date'

module Imgrb
  module Chunks


    ##
    #Instances of this class represent tEXt chunks. A text chunk contains a
    #keyword and some text (Latin-1). The following keywords are predefined
    #(taken from the PNG (Portable Network Graphics) Specification,
    #Version 1.2):
    #
    #* Title:            Short (one line) title or caption for image
    #* Author:           Name of image's creator
    #* Description:      Description of image (possibly long)
    #* Copyright:        Copyright notice
    #* Creation Time:    Time of original image creation
    #* Software:         Software used to create the image
    #* Disclaimer:       Legal disclaimer
    #* Warning:          Warning of nature of content
    #* Source:           Device used to create the image
    #* Comment:          Miscellaneous comment; conversion from GIF comment
    class ChunktEXt
      include AbstractChunk, Ancillary, Public, Safe
      def self.type
        "tEXt"
      end

      ##
      #Returns a Text object
      def get_data
        null_byte = @data.index(0.chr)
        keyword = @data[0...null_byte]
        text = @data[null_byte+1..-1]

        return Imgrb::Text.new(keyword, text)
      end
    end

    ##
    #Instances of this class represent iTXt chunks. This chunk contains UTF-8
    #encoded textual data. The chunk contains:
    #
    #* keyword (see ChunktEXt)
    #* language tag
    #* translated keyword
    #* text (possibly compressed)
    #
    #Format:
    #
    #* Keyword (Latin-1 [ISO-8859-1])
    #* Language (ISO-646)
    #* Translated keyword (UTF-8)
    #* Text (UTF-8)
    class ChunkiTXt
      include AbstractChunk, Ancillary, Public, Safe
      def self.type
        "iTXt"
      end

      ##
      #Returns a Text object
      def get_data
        #CHUNK MAY CONTAIN CHARACTERS NOT IN
        #Latin-1 character set. Testing needed to determine
        #how well UTF-8 is handled.
        data = @data

        null_byte = data.index(0.chr)
        keyword = data[0...null_byte]


        compressed = data[null_byte+1].getbyte(0) == 1
        compression_method = data[null_byte+2].getbyte(0)

        if compression_method != 0
          warn "Unknown compression method "\
          "for ancillary chunk iTXt: #{compression_method}"
        end

        data = data[null_byte+3..-1]
        null_byte = data.index(0.chr)
        language = data[0...null_byte]

        data = data[null_byte+1..-1]
        null_byte = data.index(0.chr)
        transl_keyword = data[0...null_byte]

        data = data[null_byte+1..-1]
        text = data[0..-1]

        return Imgrb::Text.new(keyword, text, compressed, true,
                               language, transl_keyword)
      end
    end

    ##
    #Instances of this class represent zTXt chunks. This chunk contains Latin-1
    #encoded textual data. The chunk contains keyword (see ChunktEXt),
    #and compressed text.
    class ChunkzTXt
      include AbstractChunk, Ancillary, Public, Safe
      def self.type
        "zTXt"
      end

      ##
      #Returns a Text object
      def get_data
        null_byte = @data.index(0.chr)
        keyword = @data[0...null_byte]
        compression_method = @data[null_byte+1].getbyte(0)
        if compression_method != 0
          warn "Unknown compression method "\
          "for ancillary chunk zTXt: #{compression_method}"
        end
        text = @data[null_byte+2..-1]
        return Imgrb::Text.new(keyword, text, true)
      end
    end


    ##
    #Instances of this class represent tIME chunks. This chunk gives information
    #on the latest image modification time and should be updated if (and only
    #if) the image data is changed and saved.
    class ChunktIME
      include AbstractChunk, Ancillary, Public, Unsafe

      def self.type
        "tIME"
      end

      ##
      #Returns a DateTime object
      def get_data
        data = @data.unpack("C*")
        year = data[0..1]
        year = Shared::interpret_bytes_2(year)
        #Year, Month, Day, Hour, Min, Sec
        return DateTime.new(year, data[2],
                  data[3], data[4],
                  data[5], data[6])
      end
    end

    ##
    #Instances of this class represent gAMA chunks. This chunk specifies the
    #relationship between the image samples and the desired display
    #output intensity. (See the PNG (Portable Network Graphics) Specification,
    #Version 1.2).
    class ChunkgAMA
      include AbstractChunk, Ancillary, Public, Unsafe

      def self.type
        "gAMA"
      end

      def get_data
        gamma = @data[0..3].unpack("C*")
        gamma = Shared::interpret_bytes_4(gamma)
        return gamma
      end

      def required_pos
        :after_IHDR
      end
    end

    ##
    #Instances of this class represent pHYs chunks. This chunk specifies the
    #intended physical dimensions of a pixel in width and height.
    class ChunkpHYs
      include AbstractChunk, Ancillary, Public, Safe

      def self.type
        "pHYs"
      end

      ##
      #Returns array of:
      #
      #* Pixel x-dimension
      #* Pixel y-dimension
      #* unit (see png spec)
      def get_data
        xd = @data[0..3].unpack("C*")
        xd = Shared::interpret_bytes_4(xd)
        yd = @data[4..7].unpack("C*")
        yd = Shared::interpret_bytes_4(yd)
        unit = @data[8].unpack("C*")[0]
        return [xd, yd, unit]
      end

      def required_pos
        :after_IHDR
      end
    end

    ##
    #Instances of this class represent oFFs chunks. This chunk gives the
    #absolute positioning of an image that is a part of e.g. a printed page.
    class ChunkoFFs
      include AbstractChunk, Ancillary, Public, Safe

      def self.type
        "oFFs"
      end

      ##
      #Returns array of:
      #
      #* x-offset
      #* y-offset
      #* the unit (see png spec)
      def get_data
        xoff = @data[0..3].unpack("C*")
        xoff = Shared::interpret_bytes_4(xoff)
        xoff = get_signed_value(xoff)

        yoff = @data[4..7].unpack("C*")
        yoff = Shared::interpret_bytes_4(yoff)
        yoff = get_signed_value(yoff)

        unit = @data[8].unpack("C*")[0]

        if !(unit == 0 || unit == 1)
          raise Imgrb::Exceptions::ChunkError,
              "Unrecognised unit value for "\
              "oFFs chunk: #{unit}."
        end

        return [xoff, yoff, unit]
      end

      def required_pos
        :after_IHDR
      end

      private
      def get_signed_value(n)
        if n.to_s(2).length == 32 #If sign bit set
          return n.to_s(2)[1..-1].to_i(2)*(-1)
        else
          return n
        end
      end

    end


    ##
    #Instances of this class represent bKGD chunks. This chunk specifies the
    #background color of the image.
    class ChunkbKGD
      include AbstractChunk, Ancillary, Public, Unsafe

      def self.type
        "bKGD"
      end

      ##
      #Returns value of background color (single value if grayscale, array of
      #3 if truecolor)
      def get_data
        #Color type 0 or 4 i.e. grayscale without or with alpha
        if @data.length == 2
          return Shared::interpret_bytes_2(@data.unpack("C*"))
        elsif @data.length == 6
          r = Shared::interpret_bytes_2(@data[0..1].unpack("C*"))
          g = Shared::interpret_bytes_2(@data[2..3].unpack("C*"))
          b = Shared::interpret_bytes_2(@data[4..5].unpack("C*"))
          return [r, g, b]
        elsif @data.length == 1
          return @data.unpack("C*")[0]
        end
      end

      def required_pos
        :after_PLTE
      end
    end


    ##
    #Instances of this class represent tRNS chunks. This chunk specifies the
    #transparency palette.
    class ChunktRNS
      include AbstractChunk, Ancillary, Public, Unsafe

      def self.type
        "tRNS"
      end

      ##
      #Returns array representing the transparency palette
      def get_data
        return @data.unpack("C*")
      end

      def required_pos
        :after_PLTE
      end
    end

    ##
    #[ONLY USED INTERNALLY]
    #NEVER write to file. Do not register.
    class ChunkskIP
      include AbstractChunk, Ancillary, Private, Unsafe

      def self.type
        "skIP"
      end

      def required_pos
        :nowhere #Skip writing this to file.
      end
    end

    #apng chunks
    #=================

    ##
    #Animation control chunk.
    #Specifies:
    #* number of frames
    #* number of loops
    class ChunkacTL
      include AbstractChunk, Ancillary, Private, Unsafe

      def self.type
        "acTL"
      end

      ##
      #Returns an array [+num_frames+, +num_plays+]
      def get_data
        dat = @data.unpack("C*")
        num_frames = Shared::interpret_bytes_4(dat[0..3])
        num_plays  = Shared::interpret_bytes_4(dat[4..7])
        return [num_frames, num_plays]
      end

      def required_pos
        :after_IHDR
      end
    end

    ##
    #Frame control chunk. Acts as a header for each animation frame.
    #Describes the following attributes:
    #* sequence number
    #* width
    #* height
    #* x-offset
    #* y-offset
    #* delay (numerator/denominator)
    #* dispose operation
    #* blend operation
    class ChunkfcTL
      include AbstractChunk, Ancillary, Private, Unsafe
      attr_reader :sequence_number, :width, :height, :x_offset, :y_offset
      def initialize(data, pos)
        super(data, pos)
        @sequence_number = Shared::interpret_bytes_4(data[0..3].unpack("C*"))
        @width           = Shared::interpret_bytes_4(data[4..7].unpack("C*"))
        @height          = Shared::interpret_bytes_4(data[8..11].unpack("C*"))
        @x_offset        = Shared::interpret_bytes_4(data[12..15].unpack("C*"))
        @y_offset        = Shared::interpret_bytes_4(data[16..19].unpack("C*"))
        @delay_num       = Shared::interpret_bytes_2(data[20..21].unpack("C*"))
        @delay_den       = Shared::interpret_bytes_2(data[22..23].unpack("C*"))
        @dispose_op      = data[24].bytes.to_a[0]
        @blend_op        = data[25].bytes.to_a[0]
      end

      ##
      #Returns a Headers::PngHeader based on the chunk data
      def to_png_header(header)
        h = header
        Imgrb::Headers::PngHeader.new(@width, @height, h.bit_depth, 0,
                                      h.image_type, 0, 0)
      end


      ##
      #Returns the delay in seconds
      def delay
        if @delay_den != 0
          @delay_num/@delay_den
        else
          @delay_num/100
        end
      end

      ##
      #Gives the name of the dispose operation:
      #* +:none+
      #* +:background+ or
      #* +:previous+
      def dispose_operation
        case @dispose_op
        when 0
          :none
        when 1
          :background
        when 2
          :previous
        end
      end

      ##
      #Gives the name of the blend operation:
      #* +:source+ or
      #* +:over+
      def blend_operation
        case @blend_op
        when 0
          :source
        when 1
          :over
        end
      end

      def self.type
        "fcTL"
      end

      def required_pos
        :apng_special #FIXME: Check if could simplify
      end
    end

    ##
    #Analogous to IDAT chunk. Used for apng frames. Also contains a 4-bytes sequence
    #number corresponding to a fcTL chunk
    class ChunkfdAT
      include AbstractChunk, Ancillary, Private, Unsafe

      def self.type
        "fdAT"
      end

      def sequence_number
        Shared::interpret_bytes_4(data[0..3].unpack("C*"))
      end

      def get_data
        return @data[4..-1]
      end

      def required_pos
        :apng_special #FIXME: Check if could simplify
      end
    end

    register_chunks(
                      ChunktEXt, ChunkiTXt, ChunkzTXt, ChunktIME,
                      ChunkgAMA, ChunkpHYs, ChunkoFFs, ChunkbKGD,
                      ChunktRNS, ChunkacTL, ChunkfcTL, ChunkfdAT
                   )



    # General purpose unknown ancillary chunks. Only used when reading image:
    # =====================================

    ##
    #General unknown, safe chunk.
    class ChunkSafe
      include AbstractChunk, Ancillary, Safe
      attr_reader :type
      def initialize(type, data, pos)
        @type = type
        super(data, pos)
      end

      ##
      #Deduce whether private/public from chunk name
      def public?
        Imgrb::PngMethods::chunk_type_public?(type)
      end

      #According to the png specification, the relative position
      #of a safe-to-copy ancillary chunk may only be relevant in
      #so far as it specifies whether the chunk appears before
      #or after IDAT. I.e. e.g. a PLTE chunk may be inserted before
      #or after an unknown safe chunk.
      def required_pos
        :unknown
      end
    end

    ##
    #General unknown, unsafe chunk.
    class ChunkUnsafe
      include AbstractChunk, Ancillary, Unsafe
      attr_reader :type
      def initialize(type, data, pos)
        @type = type
        super(data, pos)
      end

      ##
      #Deduce whether private/public from chunk name
      def public?
        Imgrb::PngMethods::chunk_type_public?(type)
      end

      def required_pos
        :unknown
      end
    end

  end
end
