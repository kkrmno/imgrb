require 'test/unit'
require 'imgrb'

class ImgrbTest < Test::Unit::TestCase


  def test_create_grayscale
    img = Imgrb::Image.new(100,50,0)
    assert_equal 100, img.width
    assert_equal 50, img.height
    assert_equal 1, img.channels
    assert_equal [100,50,1], img.size
    assert_equal [0,0], img.minmax
    assert !img.has_alpha?

    assert_raise do
      img.get_channel(1)
    end
  end

  def test_create_grayscale_with_alpha
    img = Imgrb::Image.new(2,1, [255,42])
    assert_equal 2, img.width
    assert_equal 1, img.height
    assert_equal 2, img.channels
    assert_equal [2,1,2], img.size
    assert_equal [255,255], img.get_channel(0).minmax
    assert_equal [42,42], img.get_channel(1).minmax
    assert img.has_alpha?

    assert_raise do
      img.get_channel(2)
    end
  end

  def test_create_rgb
    img = Imgrb::Image.new(600,700,[42,-1,10])
    assert_equal 600, img.width
    assert_equal 700, img.height
    assert_equal 3, img.channels
    assert_equal [600,700,3], img.size
    assert_equal [42,42], img.get_channel(0).minmax
    assert_equal [-1,-1], img.get_channel(1).minmax
    assert_equal [10,10], img.get_channel(2).minmax
    assert !img.has_alpha?

    assert_raise do
      img.get_channel(3)
    end
  end

  def test_create_rgba
    img = Imgrb::Image.new(500,1,[42,-1,10,99])
    assert_equal 500, img.width
    assert_equal 1, img.height
    assert_equal 4, img.channels
    assert_equal [500,1,4], img.size
    assert_equal [42,42], img.get_channel(0).minmax
    assert_equal [-1,-1], img.get_channel(1).minmax
    assert_equal [10,10], img.get_channel(2).minmax
    assert_equal [99,99], img.get_channel(3).minmax
    assert img.has_alpha?

    assert_raise do
      img.get_channel(4)
    end
  end

  def test_create_grayscale_from_image
    img = Imgrb::Image.new(10,10,0)
    img2 = Imgrb::Image.new(img)
    assert_equal img.size, img2.size
    assert_equal [0,0], img.minmax
    assert !img.has_alpha?
  end

  def test_create_grayscale_with_alpha_from_image
    img = Imgrb::Image.new(10,10,0)
    imga = Imgrb::Image.new(10,10,50)
    img2 = Imgrb::Image.new(img, imga)
    assert_equal img.width, img2.width
    assert_equal img.height, img2.height
    assert_equal 2, img2.channels
    assert_equal [0,0], img2.get_channel(0).minmax
    assert_equal [50,50], img2.get_channel(1).minmax
    assert img2.has_alpha?
  end

  def test_create_rgb_from_image
    imgr = Imgrb::Image.new(10,10,0)
    imgg = Imgrb::Image.new(10,10,50)
    imgb = Imgrb::Image.new(10,10,100)
    img2 = Imgrb::Image.new(imgr, imgg, imgb)
    assert_equal imgr.width, img2.width
    assert_equal imgr.height, img2.height
    assert_equal 3, img2.channels
    assert_equal [0,0], img2.get_channel(0).minmax
    assert_equal [50,50], img2.get_channel(1).minmax
    assert_equal [100,100], img2.get_channel(2).minmax
    assert !img2.has_alpha?
  end

  def test_create_rgba_from_image
    imgr = Imgrb::Image.new(10,10,0)
    imgg = Imgrb::Image.new(10,10,50)
    imgb = Imgrb::Image.new(10,10,100)
    imga = Imgrb::Image.new(10,10,42)
    img2 = Imgrb::Image.new(imgr, imgg, imgb, imga)
    assert_equal imgr.width, img2.width
    assert_equal imgr.height, img2.height
    assert_equal 4, img2.channels
    assert_equal [0,0], img2.get_channel(0).minmax
    assert_equal [50,50], img2.get_channel(1).minmax
    assert_equal [100,100], img2.get_channel(2).minmax
    assert_equal [42,42], img2.get_channel(3).minmax
    assert img2.has_alpha?
  end

  def test_create_incorrect
    assert_raise do
      Imgrb::Image.new(500,0,[42,-1,10,99])
    end
    assert_raise do
      Imgrb::Image.new(0,10,[42,-1,10])
    end
    assert_raise do
      Imgrb::Image.new(0,0,[42,-1])
    end
    assert_raise do
      Imgrb::Image.new(5,5,[42,-1,5,5,5])
    end
    assert_raise do
      Imgrb::Image.new(0,0,[])
    end
    assert_raise do
      Imgrb::Image.new(0,0)
    end
    assert_raise do
      Imgrb::Image.new(0)
    end
    img_ok = Imgrb::Image.new(10,10,5)
    assert_raise do
      Imgrb::Image.new(img_ok, img_ok, img_ok, img_ok, img_ok)
    end
  end

end
