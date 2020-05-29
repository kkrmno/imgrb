module Imgrb
  module Exif



    class ImageWidthField < GenericSingleValueField
      def self.field_name
        "ImageWidth"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 256, ImageWidthField)

    class ImageLengthField < GenericSingleValueField
      def self.field_name
        "ImageLength"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 257, ImageLengthField)


    class OrientationField < GenericSingleValueField
      def self.field_name
        "Orientation"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 274, OrientationField)


    class XResolutionField < GenericField
      def get_data
        @value.unpack(@pack_str)[0]/@value.unpack(@pack_str)[1].to_f
      end

      def self.field_name
        "XResolution"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 282, XResolutionField)

    class YResolutionField < GenericField
      def get_data
        @value.unpack(@pack_str)[0]/@value.unpack(@pack_str)[1].to_f
      end

      def self.field_name
        "YResolution"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 283, YResolutionField)

    class ResolutionUnitField < GenericField
      def get_data
        val = @value.unpack(@pack_str)[0]
        case val
        when 2
          "inches"
        when 3
          "centimeters"
        else
          "reserved (#{val})"
        end
      end

      def self.field_name
        "ResolutionUnit"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 296, ResolutionUnitField)

    class YCbCrPositioningField < GenericField
      def get_data
        val = @value.unpack(@pack_str)[0]
        case val
        when 1
          "centered"
        when 2
          "co-sited"
        else
          "reserved (#{val})"
        end
      end

      def self.field_name
        "YCbCrPositioning"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 531, YCbCrPositioningField)

    class CopyrightField < GenericField
      #May contain multiple null separated strings. First string should be
      #photographer, while second string should be the editor (where applicable).
      def get_data
        copyright_hash = Hash.new
        copyright_vals = @value.split("\x00").collect{|entry| entry.force_encoding("US-ASCII")}
        photographer = copyright_vals.fetch(0, "UNKNOWN")
        photographer = "UNKNOWN" if photographer == " "
        editor = copyright_vals.fetch(1, nil)
        others = copyright_vals[2..-1]
        copyright_hash[:photographer] = photographer
        copyright_hash[:editor] = editor unless editor.nil?
        copyright_hash[:others] = others unless others.nil?
        copyright_hash.freeze
      end

      def self.field_name
        "Copyright"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 33432, CopyrightField)


    class ExifIFDField < GenericIFDPointerField
      def self.field_name
        "ExifIFD"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 34665, ExifIFDField)



    class ComponentsConfigurationField < GenericField
      def get_data
        @value.unpack("#{@pack_str}*").collect do |component|
          case component
          when 0 then "-"
          when 1 then "Y"
          when 2 then "Cb"
          when 3 then "Cr"
          when 4 then "R"
          when 5 then "G"
          when 6 then "B"
          else
            "?"
          end
        end
      end

      def self.field_name
        "ComponentsConfiguration"
      end
    end
    register_exif_field(["ExifIFD"], 37121, ComponentsConfigurationField)

    class FlashField < GenericField
      def get_data
        val = @value.unpack(@pack_str)[0]
        flash_fired = (val & 0b1) == 1
        val >>= 1
        strobe_info_val = val & 0b11
        strobe_info = case strobe_info_val
                      when 0 then "No strobe return detection functionality"
                      when 1 then "Reserved value (#{strobe_info_val})"
                      when 2 then "No strobe return light detected"
                      when 3 then "Strobe return light detected"
                      end
        val >>= 2
        flash_mode_val = val & 0b11
        flash_mode = case flash_mode_val
                    when 0 then "Unknown value (#{flash_mode_val})"
                    when 1 then "Compulsory flash firing"
                    when 2 then "Compulsory flash suppression"
                    when 3 then "Auto flash mode"
                    end
          val >>= 1
          has_flash = (val & 0b1) == 0
          val >>= 1
          red_eye_reduction = (val & 0b1) == 1

          return {:flash_fired => flash_fired,
                  :strobe_info => strobe_info,
                  :flash_mode => flash_mode,
                  :has_flash => has_flash,
                  :red_eye_reduction => red_eye_reduction}

      end

      def self.field_name
        "Flash"
      end
    end
    register_exif_field(["ExifIFD"], 37385, FlashField)

    class UserCommentField < GenericField
      def get_data
        character_code = @value[0..7]
        encoding = case character_code
        when "ASCII\x00\x00\x00".force_encoding("ASCII-8BIT")
          "US-ASCII"
        when "JIS\x00\x00\x00\x00\x00".force_encoding("ASCII-8BIT")
          "JIS"
        when "UNICODE\x00".force_encoding("ASCII-8BIT")
          "Unicode"
        when "\x00".force_encoding("ASCII-8BIT")*8
          "UndefinedText"
        end


        text = @value[8..-1]
        case encoding
        when "US-ASCII"
          text.force_encoding("US-ASCII")
        when "Unicode"
          text.force_encoding("UTF-8")
        end

        [encoding, text]
      end

      def self.field_name
        "UserComment"
      end
    end
    register_exif_field(["ExifIFD"], 37510, UserCommentField)


    class ColorSpaceField < GenericField
      def get_data
        val = @value.unpack(@pack_str)[0]

        case val
        when 1 then "sRGB"
        when 0xFFFF then "Uncalibrated"
        else
          "reserved (#{val})"
        end
      end

      def self.field_name
        "ColorSpace"
      end
    end
    register_exif_field(["ExifIFD"], 40961, ColorSpaceField)



    class GPSIFDField < GenericIFDPointerField
      def self.field_name
        "GPS_IFD"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 34853, GPSIFDField)




  end
end
