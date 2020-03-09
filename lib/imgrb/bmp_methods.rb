module Imgrb

  #General methods used when reading/writing bmp files.
  module BmpMethods
    private
    def self.add_bmp_bytes(bmp, integer, size)
      if size == 2
        s = "v"
      elsif size == 4
        s = "V"
      else
        raise ArgumentError,
        "Only size 2 and 4 are acceptable. "\
        "Size argument given: #{size}. "
      end
      bmp << [integer].pack(s)
    end

    #Pixels are stored in reverse order (i.e. bgr) in bmp files.
    #This method switches between rgb order and bgr order
    #for image data formatted as an array of arrays (rows).
    def self.fix_bmp_reverse_pixel(image_data)
      img = Array.new(image_data.size)
      image_data.each_with_index do
        |row, i|
        index = image_data.size-1-i
        r = Array.new(row.size)
        row.each_with_index do
          |c, i|
          offset = 0
          if i % 3 == 0
            offset = 2
          elsif i % 3 == 2
            offset = -2
          end
          r[i+offset] = c
        end
        img[index] = r
      end
      return img
    end

    def self.find_multiple_of_4(num)
      (num/4.0).ceil*4
    end

    #Reconstructs correct values for fields with errors when possible
    #(e.g. BmpHeader calculates image size and the value stored in the
    #file header is ignored)
    def self.extract_bmp_header(image)
      data_offset = Imgrb::Shared::interpret_bytes_4(image[10..13].reverse)
      #DIB Header
      dib_size = Imgrb::Shared::interpret_bytes_4(image[14..17].reverse)
      width = Imgrb::Shared::interpret_bytes_4(image[18..21].reverse)
      height = Imgrb::Shared::interpret_bytes_4(image[22..25].reverse)
      color_planes = Imgrb::Shared::interpret_bytes_2(image[26..27].reverse)
      bpp = Imgrb::Shared::interpret_bytes_2(image[28..29].reverse)
      compression = Imgrb::Shared::interpret_bytes_4(image[30..33].reverse)
      horizontal_res = Imgrb::Shared::interpret_bytes_4(image[38..41].reverse)
      vertical_res = Imgrb::Shared::interpret_bytes_4(image[42..45].reverse)
      color_palette = Imgrb::Shared::interpret_bytes_4(image[46..49].reverse)
      color_palette = [] if color_palette == 0
      important_colors = Imgrb::Shared::interpret_bytes_4(image[50..53].reverse)

      Imgrb::Headers::BmpHeader.new(width, height, bpp, compression, dib_size,
                          color_planes, horizontal_res, vertical_res,
                          color_palette, important_colors, data_offset)
    end

  end
end
