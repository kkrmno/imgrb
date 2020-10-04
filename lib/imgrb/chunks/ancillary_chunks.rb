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

      #Returns a text chunk (tEXt)
      #Input:
      #* +keyword+ is a Latin-1 (ISO-8859-1) encoded string specifying the keyword (see above)
      #* +text+ is a Latin-1 (ISO-8859-1) encoded string related to the keyword
      def self.assemble(keyword, text)
        keyword_bytes = keyword.encode("ISO-8859-1").bytes.to_a
        kw_length = keyword.bytes.to_a.size
        unless 1 <= kw_length && kw_length <= 79
          raise ArgumentError, "Keyword must be 1-79 bytes long"
        end
        data = keyword_bytes.pack("C*")
        data << "\x00"
        data << text.encode("ISO-8859-1").bytes.to_a.pack("C*")
        new(data)
      end

      ##
      #Returns a Text object
      def get_data
        null_byte = @data.index(0.chr)
        if null_byte.nil?
          warn "Invalid tEXt chunk! Missing null byte."
          return Imgrb::Text.new("", @data)
        end
        keyword = @data[0...null_byte]
        if keyword.length < 1 || keyword.length > 79
          warn "Keyword length is outside proper bounds of 1-79 bytes"
        end
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

      #Returns an international text chunk (iTXt)
      #Input:
      #* +language+ is a ISO-646 encoded string specifying the language
      #* +keyword+ is a Latin-1 (ISO-8859-1) encoded string specifying the keyword (see add_text)
      #* +translated_keyword+ is a UTF-8 encoded string containing a translation of the keyword into +language+
      #* +text+ is a UTF-8 encoded string containing the text written in +language+
      def self.assemble(language, keyword, translated_keyword, text, compressed = false)
        language = language.encode("US-ASCII") #Technically alphanumeric ISO 646 with hyphens.
        keyword = keyword.encode("ISO-8859-1")
        translated_keyword = translated_keyword.encode("UTF-8")
        text = text.encode("UTF-8")

        kw_length = keyword.bytes.to_a.size
        raise ArgumentError, "Keyword must be 1-79 bytes long" unless 1 <= kw_length && kw_length <= 79

        if(compressed)
          txt = PngMethods::deflate(text)
          null_byte_compr_str = "\x00\x01\x00"
        else
          txt = text
          null_byte_compr_str = "\x00\x00\x00"
        end

        data = keyword.bytes.to_a.pack("C*")
        data << null_byte_compr_str
        data << language.bytes.to_a.pack("C*")
        data << "\x00"
        data << translated_keyword.bytes.to_a.pack("C*")
        data << "\x00"
        data << txt.bytes.to_a.pack("C*")
        new(data)
      end


      ##
      #Returns a Text object
      def get_data
        #CHUNK MAY CONTAIN CHARACTERS NOT IN
        #Latin-1 character set. Testing needed to determine
        #how well UTF-8 is handled.
        data = @data

        null_byte = data.index(0.chr)
        if null_byte.nil?
          warn "Invalid iTXt chunk! Missing null byte."
          return nil
        end
        keyword = data[0...null_byte]

        if keyword.length < 1 || keyword.length > 79
          warn "Keyword length is outside proper bounds of 1-79 bytes"
        end


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

      #Returns a compressed text chunk (zTXt)
      #Input:
      #* +keyword+ is a Latin-1 (ISO-8859-1) encoded string specifying the keyword (see add_text)
      #* +text+ is a Latin-1 (ISO-8859-1) encoded string related to the keyword
      def self.assemble(keyword, text)
        keyword_bytes = keyword.encode("ISO-8859-1").bytes.to_a
        text = text.encode("ISO-8859-1")
        kw_length = keyword.bytes.to_a.size
        unless 1 <= kw_length && kw_length <= 79
          raise ArgumentError, "Keyword must be 1-79 bytes long"
        end
        data = keyword_bytes.pack("C*")
        data << "\x00\x00"
        data << PngMethods::deflate(text)
        new(data)
      end

      ##
      #Returns a Text object
      def get_data
        null_byte = @data.index(0.chr)
        if null_byte.nil?
          warn "Invalid zTXt chunk! Missing null byte."
          return nil
        end
        keyword = @data[0...null_byte]
        if keyword.length < 1 || keyword.length > 79
          warn "Keyword length is outside proper bounds of 1-79 bytes"
        end
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


      #Returns a time chunk (tIME)
      #Input is a Time instance for the given time (UTC). The default parameter
      #value is the current time.
      def self.assemble(date = Time.now.utc)
        new(pack_time(date))
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
                  data[5], data[6], "UTC")
      end

      private
      def self.pack_time(date)
        data_bytes = [(date.year >> 8) & 0xFF, date.year & 0xFF]
        data_bytes << date.month
        data_bytes << date.day
        data_bytes << date.hour
        data_bytes << date.min
        data_bytes << date.sec
        data_bytes.pack("C*")
      end

    end

    ##
    #Instances of this class represent gAMA chunks. This chunk specifies the
    #relationship between the image samples and the desired display
    #output intensity. (See the PNG (Portable Network Graphics) Specification,
    #Version 1.2).
    class ChunkgAMA
      include AbstractChunk, Ancillary, Public, Unsafe

      #Returns a gamma chunk (gAMA)
      #Takes as input a +gamma+ value
      def self.assemble(gamma)
        gamma = (gamma*100000).round
        if gamma > 0xFFFFFFFF
          raise ArgumentError, "Given gamma value is too large to store: #{gamma}."
        end
        new([gamma].pack("L>"))
      end

      def self.type
        "gAMA"
      end

      ##
      #Returns the gamma value as a float
      #If gamma is 0 the chunk should be ignored
      def get_data
        gamma = @data[0..3].unpack("C*")
        gamma = Shared::interpret_bytes_4(gamma)/100000.0
        return gamma
      end

      ##
      #See https://www.w3.org/TR/2003/REC-PNG-20031110/#13Decoder-gamma-handling
      #To apply gamma, compute:
      #  img**decoding_exponent
      #after dividing by maximal integer for given bit depth.
      #If gamma is 0 this returns Infinity and should be ignored.
      def get_decoding_exponent(display_exponent = 2.2)
        gamma = get_data
        return 1.0/(gamma * display_exponent)
      end

      def required_pos
        :after_IHDR
      end
    end


    ##
    #Instances of this class represent cHRM chunks. This chunk specifies
    #1931 CIE x, y chromaticities and white point.
    #(See the PNG (Portable Network Graphics) Specification,
    #Version 1.2).
    class ChunkcHRM
      include AbstractChunk, Ancillary, Public, Unsafe

      #Returns a chromaticity chunk (cHRM)
      #Input:
      #* +white_x+
      #* +white_y+
      #* +red_x+
      #* +red_y+
      #* +green_x+
      #* +green_y+
      #* +blue_x+
      #* +blue_y+
      #Specifying the white point and the x, y chromaticities of r, g, b
      #display primaries.
      def self.assemble(white_x, white_y, red_x, red_y,
                        green_x, green_y, blue_x, blue_y)

        chr = [white_x, white_y, red_x, red_y, green_x, green_y, blue_x, blue_y]
        chr = chr.collect{|c| (c*100000).round}
        chr.each do |c|
          if c > 0xFFFFFFFF
            raise ArgumentError, "Given chromaticity value is too large to store: #{c}."
          end
        end
        new(chr.pack("L>*"))
      end

      def self.type
        "cHRM"
      end

      ##
      #Returns the 1931 CIE x, y chromaticities of r, g, b display primaries
      #and the white point as an arrray:
      #
      #  [white_x, white_y, red_x, red_y, green_x, green_y, blue_x, blue_y]
      def get_data
        white_x = Shared::interpret_bytes_4(@data[0..3].unpack("C*"))/100000.0
        white_y = Shared::interpret_bytes_4(@data[4..7].unpack("C*"))/100000.0
        red_x   = Shared::interpret_bytes_4(@data[8..11].unpack("C*"))/100000.0
        red_y   = Shared::interpret_bytes_4(@data[12..15].unpack("C*"))/100000.0
        green_x = Shared::interpret_bytes_4(@data[16..19].unpack("C*"))/100000.0
        green_y = Shared::interpret_bytes_4(@data[20..23].unpack("C*"))/100000.0
        blue_x  = Shared::interpret_bytes_4(@data[24..27].unpack("C*"))/100000.0
        blue_y  = Shared::interpret_bytes_4(@data[28..31].unpack("C*"))/100000.0
        return [white_x, white_y,
                red_x, red_y,
                green_x, green_y,
                blue_x, blue_y]
      end


      def required_pos
        :after_IHDR
      end
    end



    ##
    #Specifies original number of significant bits (for data originally using)
    #a sample depth unsupported by png
    class ChunksBIT
      include AbstractChunk, Ancillary, Public, Unsafe

      ##
      #Input: An array of values between 0 and 255. The number of elements should be
      #equal to the number of channels.
      #
      #The values signify the number of significant bits per channel and should
      #be less than or equal to the sample depth of the png and greater than 0.
      def self.assemble(*sbits)

        if sbits.size == 0 || sbits.size > 4
          raise ArgumentError, "Incompatible number of channels specified for sBIT: #{sbits.size}"
        end

        sbits.each do |sbit|
          if sbit > 0xFF || sbit < 0
            raise ArgumentError, "Number of significant bits greater than sample depth: #{sbit}."
          end
        end

        new(sbits.pack("C*"))
      end

      def self.type
        "sBIT"
      end

      ##
      #Returns the number of significant bits per channel in order.
      def get_data
        return @data.unpack("C*")
      end


      def required_pos
        :after_IHDR
      end
    end



    ##
    #Specifies approximate usage frequency of each color in the palette (hIST
    #chunks should only be present if the image has a PLTE chunk)
    #There is one entry per palette entry. These are proportional to the
    #fraction of pixels in the image with that palette index.
    class ChunkhIST
      include AbstractChunk, Ancillary, Public, Unsafe

      ##
      #Input: An array of values between 0 and 65535. The number of elements should be
      #equal to the number of palette entries.
      def self.assemble(*hist)

        if hist.size == 0 || hist.size > 256
          raise ArgumentError, "Incompatible number of entries specified for hIST: #{hist.size}"
        end

        hist.each do |e|
          if e > 0xFFFF || e < 0
            raise ArgumentError, "hIST entries must be between 0 and 65535: #{e}."
          end
        end

        new(hist.pack("S>*"))
      end

      def self.type
        "hIST"
      end

      ##
      #Returns the number of significant bits per channel in order.
      def get_data
        return @data.unpack("S>*")
      end


      def required_pos
        :after_IHDR
      end
    end



    ##
    #Instances of this class represent pHYs chunks. This chunk specifies the
    #intended physical dimensions of a pixel in width and height. Gives pixels
    #per unit in x and y direction, where the unit is either unknown (0) or
    #meteres (1)
    class ChunkpHYs
      include AbstractChunk, Ancillary, Public, Safe

      ##
      #Input:
      #* Pixel x-dimension
      #* Pixel y-dimension
      #* unit (see png spec)
      def self.assemble(xdim, ydim, unit)
        new([xdim, ydim, unit].pack("L>L>C"))
      end

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

      ##
      #Input:
      #
      #* x-offset
      #* y-offset
      #* the unit (see png spec)
      def self.assemble(xoff, yoff, unit)
        new([xoff, yoff, unit].pack("l>l>C"))
      end

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
        xoff, yoff, unit = @data.unpack("l>l>C")

        if !(unit == 0 || unit == 1)
          warn "Unrecognised unit value for oFFs chunk: #{unit}."
        end

        return [xoff, yoff, unit]
      end

      def required_pos
        :after_IHDR
      end

    end


    ##
    #Instances of this class represent bKGD chunks. This chunk specifies the
    #background color of the image.
    class ChunkbKGD
      include AbstractChunk, Ancillary, Public, Unsafe

      ##
      #For non-indexed images, +assemble+ takes one argument for grayscale and
      #three arguments for rgb. For indexed images, assemble takes to arugments,
      #namely the palette index as the first one, followed by :indexed.
      def self.assemble(*col)
        if col.size == 1 || col.size == 3
          new(col.pack("S>*"))
        elsif col.size == 2 && col[1] == :indexed && col[0] < 256
          new([col[0]].pack("C"))
        else
          raise ArgumentError, "Invalid background color: #{col}"
        end
      end

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

      ##
      #Input:
      #For indexed images
      #* array representing the transparency palette followed by the symbol :indexed
      #For grayscale images
      #* a single transparent value
      #For color images
      #* a single transparent color [r, g, b]
      def self.assemble(*trans_bytes)
        if trans_bytes[-1] == :indexed
          new(trans_bytes[0...-1].pack("C*"))
        else
          new(trans_bytes.pack("S>*"))
        end
      end

      def self.type
        "tRNS"
      end

      ##
      #Returns array representing the transparency palette. By default formatted
      #as if the image is an indexed image. Pass :nonindexed if rgb or grayscale
      #image.
      def get_data(format = :indexed)
        if format == :indexed
          return @data.unpack("C*")
        elsif format == :nonindexed
          return @data.unpack("S>*")
        else
          raise ArgumentError, "Unexpected format #{format}"
        end
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

      def initialize(data, pos) #:nodoc: Should not be called manually
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
          # puts "HANDLING IFD0"
          offset_to_ifd1 = collect_fields_in_IFD(offset_to_ifd0, "IFD0")
          # puts "DONE WITH IFD0"

          #If there is a IFD 1, parse it.
          if offset_to_ifd1 != 0
            # puts "HANDLING IFD 1"
            offset_to_ifd2 = collect_fields_in_IFD(offset_to_ifd1, "IFD1")
            # puts "DONE WITH IFD 1"
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

        if offset_to_next_ifd_field.nil?
          warn "Invalid IFD size for #{ifd_name}"
          offset_to_next_ifd_field = 0
        end

        [offset_to_next_ifd_field, ifd_fields]
      end

      def store_fields(fields)
        fields.each do |field|
          if field.is_IFD_pointer?
            offset_to_exif_ifd = field.get_data
            # puts "HANDLING #{field.field_name} IFD"
            offset_to_exif_ifd1 = collect_fields_in_IFD(offset_to_exif_ifd, field.field_name)
            # puts "DONE WITH #{field.field_name} IFD"
            warn "Exif contains unexpected second #{field.field_name} IFD at offset #{offset_to_exif_ifd1} (ignored)" if offset_to_exif_ifd1 != 0
          elsif field.class == Imgrb::Exif::JPEGInterchangeFormatField
            @thumbnail_start = field.get_data
          elsif field.class == Imgrb::Exif::JPEGInterchangeFormatLengthField
            @thumbnail_length = field.get_data
          else
            # puts "HANDLING #{field.field_name}"

            #Store all attributes in IFDs, except pointers to IFDs
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
    class ChunkskIP #:nodoc:
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

      ##
      #Create a new acTL chunk specifying
      #* The number of frames
      #* The number of times to loop the animation (0 for endless loop)
      def self.assemble(num_frames, num_plays)
        new([num_frames, num_plays].pack("L>L>"))
      end

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
      attr_reader :sequence_number, :width, :height, :x_offset, :y_offset,
                  :delay_num, :delay_den, :dispose_op, :blend_op

      def initialize(data, pos) #:nodoc: Should not be called manually
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

      def self.assemble(is_default_image, sequence_number, width, height,
                        x_offset, y_offset, delay_num, delay_den, dispose_op, blend_op)

        packed = [sequence_number, width, height, x_offset, y_offset,
            delay_num, delay_den, dispose_op, blend_op].pack("L>L>L>L>L>S>S>CC")

        if is_default_image
          if sequence_number != 0
            raise Exceptions::ChunkError, "If default image is part of the " \
                              "apng it must be the first image in the sequence"
          end
          return new(packed, :after_IHDR)
        else
          return new(packed, :after_IDAT)
        end
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

      def self.assemble(sequence_number, data)
        new([sequence_number].pack("L>") + data)
      end

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
                      ChunkeXIf, ChunkcHRM, ChunksBIT, ChunkhIST
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

      def initialize(type, data, pos) #:nodoc: Should not be called manually
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

      def initialize(type, data, pos) #:nodoc: Should not be called manually
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
