require 'test/unit'
require 'imgrb'

class ImgrbTest < Test::Unit::TestCase

  def assert_warn(warning_string, &block)
    actual_stderr = $stderr
    $stderr = StringIO.new
    block.call
    $stderr.rewind
    assert_equal warning_string, $stderr.string.chomp
    $stderr = actual_stderr
  end


  #Grayscale no alpha
  #=============================================================================

  def test_load_png_missing_pixel_data
    assert_warn("Image is missing 4 row(s) of pixel data. Padding with zeros.") do
      Imgrb::Image.new("test/broken_test_images/missing_pixel_data.png")
    end
  end

  def test_load_bmp_missing_pixel_data
    assert_warn("Image is missing 4 row(s) of pixel data. Padding with zeros.") do
      Imgrb::Image.new("test/broken_test_images/missing_pixel_data.bmp")
    end
  end

  def test_load_png_extra_pixel_data
    assert_warn("Image contains superfluous row(s) of pixel data that have been discarded.") do
      Imgrb::Image.new("test/broken_test_images/extra_pixel_data.png")
    end
  end

  def test_load_bmp_extra_pixel_data
    assert_warn("Image contains superfluous row(s) of pixel data that have been discarded.") do
      Imgrb::Image.new("test/broken_test_images/extra_pixel_data.bmp")
    end
  end


end
