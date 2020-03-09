module Imgrb
  module Chunks
    ##
    #Mixin module for unsafe-to-copy chunks.
    #If any changes to _critical_ chunks have been
    #made, then unrecognized unsafe chunks must
    #_not_ be copied to the output png file.
    module Unsafe
      def safe?
        return false
      end
    end
  end
end
