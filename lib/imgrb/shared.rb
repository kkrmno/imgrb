module Imgrb

  #General methods used when working with bmp or png files.
  module Shared

    def self.interpret_bytes_2(bs)
      bs = "%02X%02X" % bs
      return bs.hex
    end

    def self.interpret_bytes_4(bs)
      bs = "%02X%02X%02X%02X" % bs
      return bs.hex
    end

    #Brightness calculation.
    def self.brightness(pixel)
      pixel = Array(pixel)
      if pixel.size == 3
        return 0.2125 * pixel[0] + 0.7154 * pixel[1] + 0.0721 * pixel[2]
      elsif pixel.size == 1
        return pixel[0]
      else
        raise ArgumentError, "The brightness method only accepts grayscale or "\
                             "RGB pixels."
      end
    end


    ##
    #Not entirely correct...
    #FIXME:
    def self.ordered_dithering(image)
      mask = [[1  , 49 , 13 , 61 ,  4 , 52 , 16 , 64],
              [33 , 17 , 45 , 29 , 36 , 20 , 48 , 32],
              [9  , 57 ,  5 , 53 , 12 , 60 ,  8 , 56],
              [41 , 25 , 37 , 21 , 44 , 28 , 40 , 24],
              [3  , 51 , 15 , 63 ,  2 , 50 , 14 , 62],
              [35 , 19 , 47 , 31 , 34 , 18 , 46 , 30],
              [11 , 59 ,  7 , 55 , 10 , 58 ,  6 , 54],
              [43 , 27 , 39 , 23 , 42 , 26 , 38 , 22]]

      mask = [[1,9,3,11],
              [13,5,15,7],
              [4, 12, 2, 10],
              [16, 8, 14, 6]]

      rows = image.rows.collect.with_index do
        |row, y|
        row.collect!.with_index do
          |pixel, x|
          if pixel > (255/17.0*mask[y%4][x%4])
            #((mask[y%8][x%8]+1)*255/65.0).to_i
            mask[y%4][x%4]
          else
            0
          end
        end
      end
      Image.new(rows, image.header.image_type, 4)
    end




    ##
    #Quick check to see if a file seems to contain a bmp/png file based on the
    #file content
    def self.file_type(bytes)
      if bytes[0..1] == "BM"
        :bmp
      elsif bytes[0..7] == PngConst::PNG_START
        :png
      else
        :unknown
      end
    end

  end
end
