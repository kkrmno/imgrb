require 'test/unit'
require 'stringio'
require 'imgrb'

class ImgrbTest < Test::Unit::TestCase

  ##
  #Tests loading all valid png files in the suite, saving them again, loading
  #the re-saved images and comparing them pixelwise.
  def test_load_save_load_valid_png_files

    each_file_with_updated_info do
      |file_path|

      if @test_feature != "x"

        img = Imgrb::Image.new(file_path)
        orig_rows = img.rows

        2.times do |compression_level|
          png_io = StringIO.new
          png_io.set_encoding(Encoding::BINARY)
          img.save_to_file(png_io, :png, compression_level)
          png_str = png_io.string

          img_resaved = Imgrb::Image.new(png_str, :from_string)
          resaved_rows = img_resaved.rows
          assert orig_rows == resaved_rows, "Resaved image (at compression level: #{compression_level}) does not give same pixel data as original for image located at: #{file_path}"
        end

      end

    end


  end



  ##
  #Tests loading all valid png files in the suite that are supported for saving
  #as bmp, saving them as bmp, loading the re-saved images and comparing them
  #pixelwise.
  def test_load_save_load_valid_png_files_as_bmp

    each_file_with_updated_info do
      |file_path|

      #Valid color image with bit depth less than 16 and no transparency
      if @test_feature != "x" && @bit_depth != 16 && @test_feature != "t" &&
        (@color_type_desc == "c" || @color_type_desc == "p")

        img = Imgrb::Image.new(file_path)
        orig_rows = img.rows

        bmp_io = StringIO.new
        bmp_io.set_encoding(Encoding::BINARY)
        img.save_to_file(bmp_io, :bmp)
        bmp_str = bmp_io.string

        img_resaved = Imgrb::Image.new(bmp_str, :from_string)
        resaved_rows = img_resaved.rows

        assert orig_rows == resaved_rows, "Resaved image does not give same pixel data as original for image located at: #{file_path}"

      end

    end


  end

end
