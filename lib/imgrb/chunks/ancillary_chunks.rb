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


      def self.assemble(date)
        data_bytes = [(date.year >> 8) & 0xFF, date.year & 0xFF]
        data_bytes << date.month
        data_bytes << date.day
        data_bytes << date.hour
        data_bytes << date.min
        data_bytes << date.sec
        new(data_bytes.pack("C*"))
      end

      def self.type
        "tIME"
      end

      ##
      #Returns a DateTime object
      def get_data
        data = @data.unpack("C*")
        year = data[0..1]
        year = Shared::interpret_bytes_2(year)
        #Year, Month, Day, Hour, Min, Sec, UTC
        return Time.new(year, data[2],
                  data[3], data[4],
                  data[5], data[6], "+00:00")
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

        if !(unit == 0 || unit == 1)
          warn "Unrecognised unit value for pHYs chunk: #{unit}."
        end

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
          warn "Unrecognised unit value for oFFs chunk: #{unit}."
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
    #Chunk containing Exif profile. See "Extensions to the PNG 1.2
    #Specification", Version 1.5.0 (15 July 2017)
    class ChunkeXIf
      include AbstractChunk, Ancillary, Public, Safe

      def initialize(data, pos)
        @exif_hash = Hash.new
        super(data, pos)
      end

      def self.type
        "eXIf"
      end

      #Returns a hash containing fields that are stored in arrays associated
      #with a tag. Normally, the array should only have a single member, but in
      #case of tag collisions the fields are stored in this way. To get the data
      #of a field in a parsed format, call +get_data+
      #Example:
      # exif_hash = img.ancillary_chunks[:eXIf][0].get_data
      # img_orientation = exif_hash[:Orientation][0].get_data
      #Or to get the thumbnail image (if one exists)
      # img_thumbnail = exif_hash[:thumbnail][0].get_data
      #Note that the thumbnail is not in a compatible format (usually JPEG),
      #however if you want to write the bytes to disk, for example, to open the
      #resulting file in a compatible viewer, you may do the following:
      # IO.binwrite("thumbnail.jpg", img_thumbnail.get_data)
      #You may call
      # img_thumbnail.compression
      #to check what kind of image compression was used for the thumbnail data.
      #If you want the raw bytes you may call
      # exif_hash[:Orientation][0].value
      #If the field is of an unknown type, +get_data+ returns the values of the
      #tag in an array, combining bytes into values as specified by the tag
      #information.
      def get_data
        #First time, create hash contaning exif fields, freeze the hash, then
        #return it. For future calls, simply return the frozen hash.
        @pack_str ||= get_pack_str

        if @pack_str == ""
          warn "Unknown Exif format!"
          return self.data
        end


        if @exif_hash.empty?
          @thumbnail_start = -1
          @thumbnail_length = -1

          #Image File Directory (IFD)
          #Number of IFDs should be at most 2
          #IFD 0 records attribute information
          #IFD 0 may contain an ExifIFD
          #IFD 1 records thumbnail image
          # puts "HANDLING IFD 0"
          offset_to_ifd0 = data[4..7].unpack(@pack_str.upcase)[0]
          offset_to_ifd1 = collect_fields_in_IFD(offset_to_ifd0, "IFD0")

          #If there is a IFD 1, parse it.
          if offset_to_ifd1 != 0
            # puts "HANDLING IFD 1"
            offset_to_ifd2 = collect_fields_in_IFD(offset_to_ifd1, "IFD1")
            warn "Exif contains unexpected IFD 2 at offset #{offset_to_ifd2} (ignored)" if offset_to_ifd2 != 0
          end

          # puts "Extracting thumbnail"
          thumbnail = extract_thumbnail
          if thumbnail
            @exif_hash[:thumbnail] ||= []
            @exif_hash[:thumbnail] << thumbnail
          end

        end

        @exif_hash.freeze
      end


      def required_pos
        #Stricter than necessary, but compliant
        :after_IHDR
      end


      private

      def when_read(data)
        if data.size > 2**16-9
          warn "Exif data too large to fit into a JPEG APP1 marker (Exif) segment!"
        end

        @pack_str = get_pack_str

        if @pack_str == ""
          warn "Unknown Exif format!"
        end
      end

      def get_pack_str
        endian_str = data[0..3]
        pack_str = ""

        #II (little-endian)
        if endian_str == [73, 73, 42, 0].pack("C*")
          pack_str = "v"
        #MM (big-endian)
        elsif endian_str == [77, 77, 0, 42].pack("C*")
          pack_str = "n"
        end
        return pack_str
      end

      def collect_fields_in_IFD(offset, ifd_name)
        offset_to_next_ifd, fields = parse_IFD(offset, ifd_name)
        store_fields(fields)
        return offset_to_next_ifd
      end

      def parse_IFD(offset, ifd_name)
        num_ifd_fields = data[offset..offset+1].unpack(@pack_str)[0]
        ifd_fields = []

        num_ifd_fields.times do |field|
          # puts "\tFIELD #{field}"
          field_data = data[offset+2+field*12...offset+2+(field+1)*12]
          exif_field = Imgrb::Exif.create_field(field_data, @pack_str, data, ifd_name)

          # puts "\tHandling field data: #{exif_field}"
          # puts

          ifd_fields << exif_field
        end

        offset_to_next_ifd_field = data[offset+2+(num_ifd_fields)*12..offset+2+(num_ifd_fields)*12+3].unpack(@pack_str.upcase)[0]

        [offset_to_next_ifd_field, ifd_fields]
      end

      def store_fields(fields)
        fields.each do |field|
          if field.is_IFD_pointer?
            offset_to_exif_ifd = field.get_data
            # puts "HANDLING #{field.field_name} IFD"
            offset_to_exif_ifd1 = collect_fields_in_IFD(offset_to_exif_ifd, field.field_name)
            warn "Exif contains unexpected second #{field.field_name} IFD at offset #{offset_to_exif_ifd1} (ignored)" if offset_to_exif_ifd1 != 0
          elsif field.class == Imgrb::Exif::JPEGInterchangeFormatField
            @thumbnail_start = field.get_data
          elsif field.class == Imgrb::Exif::JPEGInterchangeFormatLengthField
            @thumbnail_length = field.get_data
          else
            #Store all attributes in IFD0, except pointers to IFDs
            @exif_hash[field.field_name.to_sym] ||= []
            @exif_hash[field.field_name.to_sym] << field
          end
        end
      end

      def extract_thumbnail
        if @thumbnail_start >= 0 && @thumbnail_length > 0
          thumbnail_data = data[@thumbnail_start..@thumbnail_start+@thumbnail_length+1]
          thumbnail = Imgrb::Exif::Thumbnail.new(thumbnail_data, @exif_hash[:Compression][0].get_data)
        else
          thumbnail = nil
        end
        return thumbnail
      end

    end

    ##
    #[ONLY USED INTERNALLY]
    #NEVER write to file. Do not register.
    #TODO: REMOVE!
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









    #Register specified chunks
    register_chunks(
                      ChunktEXt, ChunkiTXt, ChunkzTXt, ChunktIME,
                      ChunkgAMA, ChunkpHYs, ChunkoFFs, ChunkbKGD,
                      ChunktRNS, ChunkacTL, ChunkfcTL, ChunkfdAT,
                      ChunkeXIf
                   )



    # General purpose unknown ancillary chunks. Only used when reading image:
    # =====================================

    ##
    #General unknown, safe chunk. Used when encountering unknown, safe chunks
    #when reading a png file.
    class ChunkSafe
      include AbstractChunk, Ancillary, Safe
      #Returns the chunk type name (four characters as specified in the png spec)
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

      #The relative position of a safe-to-copy ancillary chunk is only relevant
      #in so far as it specifies whether the chunk appears before or after IDAT.
      #I.e., e.g. a PLTE chunk may be inserted before
      #or after an unknown safe chunk.
      def required_pos
        :unknown
      end
    end

    ##
    #General unknown, unsafe chunk. Used when encountering unknown, unsafe chunks
    #when reading a png file.
    class ChunkUnsafe
      include AbstractChunk, Ancillary, Unsafe
      #Returns the chunk type name (four characters as specified in the png spec)
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

      #The relative position of an unsafe-to-copy ancillary chunk does not change
      #with respect to critical chunks, thus respecting the png spec.
      def required_pos
        :unknown
      end
    end

  end
end
