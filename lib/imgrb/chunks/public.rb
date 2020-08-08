module Imgrb
  module Chunks
    ##
    #Mixin module for publically defined chunks.
    #Chunks that are officially registered must
    #be public.
    #All classes of public chunks should include this module!
    module Public
      def public?
        return true
      end
    end
  end
end
