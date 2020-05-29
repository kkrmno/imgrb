module Imgrb
  module Exif


    class MakeField < GenericSingleAsciiField
      def self.field_name
        "Make"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 271, MakeField)

    class ModelField < GenericSingleAsciiField
      def self.field_name
        "Model"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 272, ModelField)

    class SoftwareField < GenericSingleAsciiField
      def self.field_name
        "Software"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 305, SoftwareField)

    class ArtistField < GenericSingleAsciiField
      def self.field_name
        "Artist"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 315, ArtistField)








    class ExifVersionField < GenericSingleAsciiNZField
      def self.field_name
        "ExifVersion"
      end
    end
    register_exif_field(["ExifIFD"], 36864, ExifVersionField)

    class FlashpixVersionField < GenericSingleAsciiNZField
      def self.field_name
        "FlashpixVersion"
      end
    end
    register_exif_field(["ExifIFD"], 40960, FlashpixVersionField)

  end
end
