module Imgrb
  module Chunks
    ##
    #Mixin module for privately defined chunks.
    #Chunks that are user defined (not following
    #officially registered specification) must
    #be private (and thus should include this module).
    #All classes of private chunks should include this module!
    module Private
      def public? #:nodoc:
        return false
      end
    end
  end
end
