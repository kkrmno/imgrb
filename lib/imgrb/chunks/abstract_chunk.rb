module Imgrb
  module Chunks
    #This is a mixin module that provides basic functionality for chunk classes.
    #If classes provide their own initialize method, it should call super.
    module AbstractChunk
      attr_reader :data, :pos
      ##
      #* +data+ contains the packed data inside the chunk
      #* +pos+ is the required position (e.g. after IDAT)
      #
      #When a new chunk is created, checks that the naming rules
      #are followed (see png documentation regarding chunk names)
      def initialize(data, pos = required_pos)
        @data = data
        @pos = pos

        if data.size > 2**31-1
          raise Imgrb::Exceptions::ChunkError,
                "Trying to create a chunk exceeding the maximum length!"
        end
        check_name_integrity
        when_read(data)
      end

      ##
      #Override if chunk has requirement on its position
      def required_pos
        :none
      end

      ##
      #Must be overriden when implementing a chunk. Should
      #return a compliant four letter chunk name.
      def type
        if self.class.respond_to?(:type)
          return self.class.type
        else
          raise Imgrb::Exceptions::ChunkError, "Chunk class with "\
                                               "undeclared class method "\
                                               "'type'."
        end
      end

      #You may override this method in user-defined chunks. Called when
      #initializing chunk, with input +data+ containing the packed data
      #contained in the chunk.
      def when_read(data)
        nil
      end

      ##
      #Return CRC of chunk
      def crc
        [Zlib.crc32(type + @data, 0)].pack('N')
      end

      ##
      #Returns the data part of the chunk as bytes (override for chunks if more
      #specific format is desired).
      def get_data
        return @data
      end

      #Returns the chunk as bytes
      def get_raw
        return [@data.size].pack('N') << type << @data << crc
      end

      private
      ##
      #Checks that the chunk name follows the rules laid out in the png spec.
      def check_name_integrity
        if !(/\A[a-zA-Z]{4}\z/ =~ type)
          raise Imgrb::Exceptions::HeaderError, "Chunk name '#{type}' must "\
                                                "be four ASCII letters."
        elsif !critical? && !Imgrb::PngMethods::chunk_type_ancillary?(type)
          raise Imgrb::Exceptions::HeaderError, "Chunk name '#{type}' "\
                                                "indicates that this chunk is "\
                                                "critical, but it was "\
                                                "expected "\
                                                "to be ancillary. Ancillary chunks "\
                                                "may not use uppercase for "\
                                                "the first letter!"
        elsif critical? && Imgrb::PngMethods::chunk_type_ancillary?(type)
          raise Imgrb::Exceptions::HeaderError, "Chunk name '#{type}' "\
                                                "indicates that this chunk is "\
                                                "ancillary, but it was "\
                                                "expected "\
                                                "to be critical. Critical chunks "\
                                                "must use uppercase for "\
                                                "the first letter!"
        elsif Imgrb::PngMethods::chunk_type_safe?(type) != safe?
          raise Imgrb::Exceptions::HeaderError, "Chunk name '#{type}' does "\
                                          "not match safe flag "\
                                          "'#{safe?}'. Either change "\
                                          "name to "\
                                          "'#{type[0..2]<<type[3].swapcase}', "\
                                          "or change the safety status of "\
                                          "the chunk!"
        elsif Imgrb::PngMethods::chunk_type_reserved?(type)
          raise Imgrb::Exceptions::HeaderError, "Chunk name '#{type}' is "\
                                                "reserved. The chunk name may "\
                                                "not use lowercase for the "\
                                                "third letter!"
        elsif Imgrb::PngMethods::chunk_type_public?(type) != public?
          raise Imgrb::Exceptions::HeaderError, "Chunk name '#{type} does not "\
                                  "match private/public flag "\
                                  "'#{public?}'. Either change name to "\
                                  "'#{type[0]<<type[1].swapcase<<type[2..3]}' "\
                                  "or change the private/public satus "\
                                  "of the chunk!"
        end
      end
    end
  end
end
