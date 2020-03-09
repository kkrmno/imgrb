module Imgrb
  module Chunks
    ##
    #Mixin module for ancillary chunks.
    #Ancillary chunks may _always_ be ignored.
    #Should +include+ in ancillary chunks
    #
    #
    #To specify a new ancillary
    #chunk you should include the mixins for the base
    #chunk and the ancillary mixin. Also include the
    #other appropriate mixins based on the chunk (i.e.
    #'Safe'/'Unsafe', 'Public'/'Private').
    #
    #The order may be significant, so the mixins should be included
    #in the following order:
    #AbstractChunk first, followed by the other mixins.
    #
    #If something should happen when the data belonging to a chunk
    #is loaded from an image, then specify this by overriding the
    #'when_read(data)' method. This method is called automatically
    #when a chunk is initialized.
    #
    #==Example
    #
    # class MyChunk
    #   include Imgrb::Chunks::AbstractChunk, Imgrb::Chunks::Ancillary,
    #           Imgrb::Chunks::Private, Imgrb::Chunks::Safe
    #
    #   def required_pos
    #     :after_IDAT
    #   end
    #
    #   def when_read(data)
    #     @unpacked_data = data.unpack('C*')
    #     p @unpacked_data[0..2] #Inspect first three bytes.
    #   end
    #
    #   def self.type
    #     "myCh"
    #   end
    # end
    #
    #Note that the chunk name specified by the return value of "type" is
    #significant. It must be exactly four ASCII characters and each character
    #must be of the correct case (upper/lower), so that it conforms to the
    #ancillary/critical, safe/unsafe, and private/public status indicated by
    #the included mixins. The chunk name is checked when a new instance is
    #created and an exception is raised if the name is incorrect. See the
    #png specification for more info.
    #
    #If you do not override the "required_pos" method
    #":none" is the default. This method specifies any requirements on where
    #the chunk is positioned in the image if saved as a png.
    #The options are:
    #
    #* :none
    #* :after_IHDR
    #* :after_PLTE
    #* :after_IDAT
    #
    #See README for more examples
    module Ancillary

      ##
      #Ancillary chunks are not critical. Returns false.
      def critical?
        return false
      end

      #The critical chunk after which this ancillary
      #chunk has to _immediately_ appear (disregarding
      #other ancillary chunks).
      #
      #== Options:
      #
      #* +:none+
      #* +:after_IHDR+
      #* +:after_PLTE+
      #* +:after_IDAT+
      #* (+:unknown+)       <- Internal use only!
      #
      def required_pos
        return :none
      end
    end
  end
end
