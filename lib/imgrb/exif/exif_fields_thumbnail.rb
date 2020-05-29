module Imgrb
  module Exif

    class CompressionField < GenericField
      def get_data
        val = @value.unpack(@pack_str)[0]

        case val
        when 1 then "uncompressed"
        when 6 then "JPEG compression (thumbnail only)"
        else
          "reserved (#{val})"
        end
      end

      def self.field_name
        "Compression"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 259, CompressionField)


    class JPEGInterchangeFormatField < GenericSingleValueField
      def self.field_name
        "JPEGInterchangeFormat"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 513, JPEGInterchangeFormatField)

    class JPEGInterchangeFormatLengthField < GenericSingleValueField
      def self.field_name
        "JPEGInterchangeFormatLength"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 514, JPEGInterchangeFormatLengthField)



    class Thumbnail
      attr_reader :compression
      def initialize(data, compression)
        @data = data
        @compression = compression
      end

      def get_data
        return @data
      end
    end

  end
end
