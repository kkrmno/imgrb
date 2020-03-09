module Imgrb
  module Chunks
    ##
    #Mixin module for safe-to-copy chunks.
    #Chunks that are safe-to-copy can always
    #be copied to a modified (or not) png file.
    module Safe
      def safe?
        return true
      end
    end
  end
end
