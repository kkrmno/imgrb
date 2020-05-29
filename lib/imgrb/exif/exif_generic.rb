module Imgrb
  module Exif


    ##
    #Most generic Exif-field class.
    class GenericField
      attr_reader :tag_number, :value
      def initialize(tag_number, value, type, pack_str)
        @tag_number = tag_number
        @value = value
        @type = type
        @pack_str = pack_str
      end

      def get_data
        unpacked = @value.unpack("#{@pack_str}*")
        values = unpacked
        if @type == :rational || @type == :srational
          values = []
          0.step(unpacked.size-1,2) do |idx|
            num = unpacked[idx]
            den = unpacked[idx+1]
            values << Rational(num, den)
          end
        end

        return values
      end

      def to_s
        "Exif:#{field_name}: #{get_data}"
      end

      def is_IFD_pointer?
        false
      end

      def self.field_name
        nil
      end

      def field_name
        if self.class.field_name
          self.class.field_name
        else
          "UNKNOWN (tag:#{@tag_number}, type:#{@type.to_s}, pack_str:#{@pack_str})"
        end
      end
    end

    ##
    #Generic class for Exif-fields containing a single value (i.e. count = 1).
    class GenericSingleValueField < GenericField
      def get_data
        @value.unpack(@pack_str)[0]
      end
    end

    ##
    #Generic Exif-field _pointer_ class (e.g. used by ExifIFDField)
    #Creates a new IFD entry in the registry.
    class GenericIFDPointerField < GenericSingleValueField
      def is_IFD_pointer?
        true
      end
    end


    ##
    #Generic Exif-field class for fields containing a single ASCII string.
    class GenericSingleAsciiField < GenericField
      def get_data
        @value.force_encoding("US-ASCII")[0...-1]
      end
    end

    ##
    #Generic Exif-field class for fields containing a single ASCII string
    #without null terminator.
    class GenericSingleAsciiNZField < GenericField
      def get_data
        @value.force_encoding("US-ASCII")
      end
    end




  end
end
