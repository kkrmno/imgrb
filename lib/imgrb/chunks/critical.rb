module Imgrb
  module Chunks
    ##
    #Mixin module for critical chunks.
    #Critical chunks may _never_ be ignored.
    #If a chunk is critical, it is also
    #implicitly unsafe to copy.
    module Critical
      include Imgrb::Chunks::Unsafe

      def critical?
        return true
      end


      #The 'required_pos' of a critical chunk should
      #_always_ return ':critical'!
      def required_pos
        return :critical
      end
    end
  end
end
