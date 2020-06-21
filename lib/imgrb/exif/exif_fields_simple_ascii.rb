module Imgrb
  module Exif


    class MakeField < GenericSingleAsciiField
      def self.field_name
        "Make"
      end

      def self.tag
        271
      end
    end

    class ModelField < GenericSingleAsciiField
      def self.field_name
        "Model"
      end

      def self.tag
        272
      end
    end

    class SoftwareField < GenericSingleAsciiField
      def self.field_name
        "Software"
      end

      def self.tag
        305
      end
    end

    class ArtistField < GenericSingleAsciiField
      def self.field_name
        "Artist"
      end

      def self.tag
        315
      end
    end





    class ExifVersionField < GenericSingleAsciiNZField
      def self.field_name
        "ExifVersion"
      end

      def self.tag
        36864
      end

      def self.possible_IFDs
        "ExifIFD"
      end
    end

    class FlashpixVersionField < GenericSingleAsciiNZField
      def self.field_name
        "FlashpixVersion"
      end

      def self.tag
        40960
      end

      def self.possible_IFDs
        "ExifIFD"
      end
    end



    register_exif_fields(MakeField, ModelField, SoftwareField, ArtistField,
                         ExifVersionField, FlashpixVersionField)
                         
  end
end
