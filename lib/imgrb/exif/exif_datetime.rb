module Imgrb
  module Exif




    class DateTimeField < GenericField
      def get_data
        val = @value.force_encoding("US-ASCII")
        date = val[0..9].split(":")
        time = val[11..-2].split(":") #Skip null byte
        if date.length == 3 && time.length == 3 && date[0][0] != " "
          year = date[0].to_i
          month = date[1].to_i
          day = date[2].to_i

          hour = time[0].to_i
          minute = time[1].to_i
          second = time[2].to_i

          return Time.new(year, month, day, hour, minute, second, "+00:00")
        else
          return "Unknown"
        end
      end

      def self.field_name
        "DateTime"
      end
    end
    register_exif_field(["IFD0", "IFD1"], 306, DateTimeField)

    ##
    #Same as DateTimeField, but may have a different time and signifies specifically
    #when the original image was created
    class DateTimeOriginalField < DateTimeField
      def self.field_name
        "DateTimeOriginal"
      end
    end
    register_exif_field("ExifIFD", 36867, DateTimeOriginalField)

    ##
    #Same as DateTimeField, but may have a different time and signifies specifically
    #when the image was stored as digital data.
    class DateTimeDigitizedField < DateTimeField
      def self.field_name
        "DateTimeDigitized"
      end
    end
    register_exif_field("ExifIFD", 36868, DateTimeDigitizedField)


  end
end
