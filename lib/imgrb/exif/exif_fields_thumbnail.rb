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

      def self.tag
        259
      end
    end

    class JPEGInterchangeFormatField < GenericSingleValueField
      def self.field_name
        "JPEGInterchangeFormat"
      end

      def self.tag
        513
      end
    end

    class JPEGInterchangeFormatLengthField < GenericSingleValueField
      def self.field_name
        "JPEGInterchangeFormatLength"
      end

      def self.tag
        514
      end
    end



    register_exif_fields(CompressionField, JPEGInterchangeFormatField, JPEGInterchangeFormatLengthField)

  
    #End of Exif exif-fields
    #=======================================



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
