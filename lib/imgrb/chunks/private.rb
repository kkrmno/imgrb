module Imgrb
  module Chunks
    ##
    #Mixin module for privately defined chunks.
    #Chunks that are user defined (not following
    #officially registered specification) must
    #be private (and thus should include this module).
    module Private
      def public?
        return false
      end
    end
  end
end
