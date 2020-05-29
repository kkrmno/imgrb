require 'test/unit'
require 'imgrb'

class ImgrbTest < Test::Unit::TestCase

  ##
  #Tests Exif chunk
  #TODO: Add more test images.
  def test_png_exif_chunk

    img = Imgrb::Image.new("test/png_test_suite/exif2c08.png")
    assert_equal img.ancillary_chunks.keys, [:eXIf]
    assert_equal img.ancillary_chunks[:eXIf].size, 1
    assert_equal img.ancillary_chunks[:eXIf][0].get_data.keys, [:Orientation,
                :XResolution, :YResolution, :ResolutionUnit, :YCbCrPositioning,
                :Copyright, :ExifVersion, :ComponentsConfiguration, :UserComment,
                :FlashpixVersion, :ColorSpace, :Compression, :thumbnail]

    exif_data = img.ancillary_chunks[:eXIf][0].get_data
    assert_equal exif_data[:Orientation][0].get_data, 1
    assert_equal exif_data[:XResolution][0].get_data, 72.0
    assert_equal exif_data[:YResolution][0].get_data, 72.0
    assert_equal exif_data[:ResolutionUnit][0].get_data, "inches"
    assert_equal exif_data[:YCbCrPositioning][0].get_data, "centered"
    assert_equal exif_data[:Copyright][0].get_data[:photographer], "2017 Willem van Schaik"
    assert_equal exif_data[:ExifVersion][0].get_data, "0220"
    assert_equal exif_data[:ComponentsConfiguration][0].get_data, ["Y", "Cb", "Cr", "-"]
    assert_equal exif_data[:UserComment][0].get_data, ["US-ASCII", "PngSuite"]
    assert_equal exif_data[:FlashpixVersion][0].get_data, "0100"
    assert_equal exif_data[:ColorSpace][0].get_data, "Uncalibrated"
    assert_equal exif_data[:Compression][0].get_data, "JPEG compression (thumbnail only)"
    assert_equal exif_data[:thumbnail][0].get_data.index("JFIF"), 6

  end

end
