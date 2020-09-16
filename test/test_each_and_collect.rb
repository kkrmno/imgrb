require 'test/unit'
require 'imgrb'

class ImgrbTest < Test::Unit::TestCase


  def test_each
    row = [-1,0,1,2.5,100]
    img = Imgrb::Image.new(row.size, 5, 0)
    img.height.times do |y|
      img[y] = row
    end

    img_rgba = Imgrb::Image.new(img, img, img, img)

    img.each.with_index do |value, idx|
      idx_mod = idx % img.width
      expected_value = row[idx_mod]

      assert_equal expected_value, value
    end

    img_rgba.each.with_index do |value, idx|
      idx_mod = idx % img_rgba.width
      expected_value = [row[idx_mod]]*4

      assert_equal expected_value, value
    end
  end

  def test_collect
    row = [-1,0,1,2.5,100]
    row_sq = row.collect{|v| v**2}
    img = Imgrb::Image.new(row.size, 5, 0)
    img.height.times do |y|
      img[y] = row
    end

    img_rgba = Imgrb::Image.new(img, img, img, img)

    img_squared = img.collect_to_image do |val|
      val**2
    end

    img_rgba_squared = img_rgba.collect_channels_to_image do |channel|
      channel.collect_to_image do |val|
        val**2
      end
    end

    img_squared.each_row do |row_squared|
      assert_equal row_sq, row_squared
    end

    img_rgba_squared.each_channel do |channel|
      channel.each_row do |row_squared|
        assert_equal row_sq, row_squared
      end
    end
  end


  def test_collect_with_coord
    img = Imgrb::Image.new(10,10,[0,1,2])

    img = img.collect_to_image_with_coord do |val, x, y|
      val.collect{|v| v*(x+y)}
    end

    img.height.times do |y|
      img.width.times do |x|
        val = img[y,x]
        expected_val = [0, x+y, 2*(x+y)]

        assert_equal expected_val, val
      end
    end


    img.each_with_coord do |val, x, y|
      assert_equal val, img[y, x]
    end
  end




end
