module Imgrb
  module Chunks
    #Instances of this class represent IDAT chunks. This chunk contains
    #compressed image data.
    class ChunkIDAT
      include AbstractChunk, Critical, Public

      def self.type
        "IDAT"
      end

    end

    #Instances of this class represent IHDR chunks. This chunk contains header
    #data. It must be the first chunk in a PNG file. It contains data on
    #* width
    #* height
    #* bit depth
    #* color type
    #* compression method (only one possible)
    #* filter method (only one possible)
    #* interlace method (none or Adam7)
    class ChunkIHDR
      include AbstractChunk, Critical, Public

      def self.type
        "IHDR"
      end

      ##
      #Returns a Imgrb::Headers::PngHeader
      def get_data
        data = @data.unpack("C*")
        width = Shared::interpret_bytes_4(data[0..3])
        height = Shared::interpret_bytes_4(data[4..7])
        bit_depth = data[8]
        color_type = data[9]
        compression = data[10]
        filter = data[11]
        interlace = data[12]
        return Imgrb::Headers::PngHeader.new(width, height,
                   bit_depth, compression,
                   color_type, filter, interlace)
      end
    end

    #Instances of this class represent PLTE chunks. This chunk contains the
    #palette data for those color types that require (or allow) it.
    class ChunkPLTE
      include AbstractChunk, Critical, Public

      def self.type
        "PLTE"
      end

      ##
      #Returns array of palette bytes
      def get_data
        return @data.unpack("C*")
      end
    end

    #Instances of this class represent IEND chunks. This chunk must appear last
    #in a PNG file. It marks the end of the datastream.
    class ChunkIEND
      include AbstractChunk, Critical, Public

      def self.type
        "IEND"
      end

      ##
      #The IEND chunk does not contain any data.
      def get_data
        return nil
      end
    end


    register_chunks(ChunkIDAT, ChunkIHDR, ChunkPLTE, ChunkIEND)


  end
end