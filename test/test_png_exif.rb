require 'test/unit'
require 'imgrb'

class ImgrbTest < Test::Unit::TestCase

  ##
  #Tests Exif chunk
  #TODO: Add more test images.
  def test_png_exif_chunk

    img = Imgrb::Image.new("test/png_test_suite/exif2c08.png")
    assert_equal [:eXIf], img.ancillary_chunks.keys
    assert_equal 1, img.ancillary_chunks[:eXIf].size
    assert_equal [:Orientation, :XResolution, :YResolution, :ResolutionUnit,
                  :YCbCrPositioning, :Copyright, :ExifVersion,
                  :ComponentsConfiguration, :UserComment, :FlashpixVersion,
                  :ColorSpace, :Compression, :thumbnail],
                  img.ancillary_chunks[:eXIf][0].get_data.keys,

    exif_data = img.ancillary_chunks[:eXIf][0].get_data
    assert_equal 1, exif_data[:Orientation][0].get_data
    assert_equal 72.0, exif_data[:XResolution][0].get_data
    assert_equal 72.0, exif_data[:YResolution][0].get_data
    assert_equal "inches", exif_data[:ResolutionUnit][0].get_data
    assert_equal "centered", exif_data[:YCbCrPositioning][0].get_data
    assert_equal "2017 Willem van Schaik", exif_data[:Copyright][0].get_data[:photographer]
    assert_equal "0220", exif_data[:ExifVersion][0].get_data
    assert_equal ["Y", "Cb", "Cr", "-"], exif_data[:ComponentsConfiguration][0].get_data
    assert_equal ["US-ASCII", "PngSuite"], exif_data[:UserComment][0].get_data
    assert_equal "0100", exif_data[:FlashpixVersion][0].get_data
    assert_equal "Uncalibrated", exif_data[:ColorSpace][0].get_data
    assert_equal "JPEG compression (thumbnail only)", exif_data[:Compression][0].get_data
    assert_equal 6, exif_data[:thumbnail][0].get_data.index("JFIF")

  end

end
