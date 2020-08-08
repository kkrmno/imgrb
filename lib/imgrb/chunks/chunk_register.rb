module Imgrb
  module Chunks

    @registered_chunks = {}

    ##
    #Returns the chunk Class object corresponding to the given +name+
    def self.get_chunk_class(name)
      @registered_chunks[name]
    end

    ##
    #Register a chunk class so that pngs containing a matching
    #chunk type can be understood
    def self.register_chunk(klass)
      @registered_chunks[klass.type] = klass
    end

    ##
    #Register several chunks
    def self.register_chunks(*klasses)
      klasses.each do
        |klass|
        register_chunk(klass)
      end
    end

    ##
    #Returns an array of names of all registered chunks
    def self.registered_chunks
      @registered_chunks.keys
    end

    #TODO: Unregister chunks?
  end
end
