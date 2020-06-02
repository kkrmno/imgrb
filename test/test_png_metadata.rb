require 'test/unit'
require 'imgrb'

class ImgrbTest < Test::Unit::TestCase

  def interpret_file_name(file_name)

    @test_feature = file_name[0]
    @parameter = file_name[1..2]
    @is_interlaced = file_name[3] == "i"
    @color_type_num = file_name[4].to_i
    @color_type_desc = file_name[5]
    @bit_depth = file_name[6..7].to_i

  end

  def each_file_with_updated_info(&block)
    Enumerator.new {
      |f|
      Dir["test/png_test_suite/*.png"].each do
        |file_path|
        file_name = file_path.split("/")[-1]
        next if file_name == "PngSuite.png" #Skip the PngSuite logo
        interpret_file_name(file_name)

        f << file_path
      end
    }.each(&block)
  end

  def save_png_to_string(img, compression_level = 0)
    png_io = StringIO.new
    png_io.set_encoding(Encoding::BINARY)
    img.save_to_file(png_io, :png, compression_level)
    png_io.string
  end

  ##
  #Tests loading all invalid png files in the suite. Should reading metadata
  #be allowed if the IDAT chunk is missing? Should there be an option to allow
  #reading png files failing crc check?
  def test_load_invalid_png_files

    each_file_with_updated_info do
      |file_path|

      if @test_feature == "x"
        #Invalid png files should generally raise exception (except in the case below).
        assert_raise do
          Imgrb::Image.new(file_path)
        end

        #Reading only metadata should not(?) raise an error if IDAT chunk is
        #missing.
        if @parameter == "dt"
          assert_nothing_raised do
            Imgrb::Image.new(file_path, :only_metadata)
          end
        end

      end

    end

  end

  ##
  #Tests all png files with text metadata in the png suite.
  def test_png_text_metadata

    keywords = ["Title", "Author", "Copyright", "Description", "Software", "Disclaimer"]

    each_file_with_updated_info do
      |file_path|

      #Valid png with text metadata
      if @test_feature == "c" && @parameter[0] == "t"

        img = Imgrb::Image.new(file_path, :only_metadata)

        text_type = @parameter[1]
        if text_type == "0"
          assert img.texts.empty?, "Image does not contain text metadata, but img.texts is not empty!"
        elsif text_type == "1" || text_type == "z"
          assert_equal 6, img.texts.size
          img.texts.each do
            |txt|
            assert keywords.include? txt.keyword
            assert txt.text.length > 0
          end
          #img.texts.each{|txt| txt.report}
        elsif text_type == "e"
          assert_equal 6, img.texts.size
          img.texts.each do
            |txt|
            assert txt.international?
            assert_equal "en".force_encoding("646"), txt.language
            assert keywords.include? txt.keyword
            assert_equal txt.translated_keyword, txt.keyword
            assert txt.text.length > 0
          end
        elsif text_type == "f"
          assert_equal 6, img.texts.size
          img.texts.each do
            |txt|
            assert txt.international?
            assert_equal "fi".force_encoding("646"), txt.language
            assert keywords.include? txt.keyword
            assert txt.translated_keyword.length > 0
            assert txt.text.length > 0
          end
        elsif text_type == "g"
          assert_equal 6, img.texts.size
          img.texts.each do
            |txt|
            assert txt.international?
            assert_equal "el".force_encoding("646"), txt.language
            assert keywords.include? txt.keyword
            assert txt.translated_keyword.length > 0
            assert txt.text.length > 0
          end
        elsif text_type == "h"
          assert_equal 6, img.texts.size
          img.texts.each do
            |txt|
            assert txt.international?
            assert_equal "hi".force_encoding("646"), txt.language
            assert keywords.include? txt.keyword
            assert txt.translated_keyword.length > 0
            assert txt.text.length > 0
          end
        elsif text_type == "j"
          assert_equal 6, img.texts.size
          img.texts.each do
            |txt|
            assert txt.international?
            assert_equal "ja".force_encoding("646"), txt.language
            assert keywords.include? txt.keyword
            assert txt.translated_keyword.length > 0
            assert txt.text.length > 0
          end
        end
      end
    end

  end

  ##
  #Tests all the images with tIME chunks in the png suite.
  def test_png_time_metadata
    each_file_with_updated_info do
      |file_path|

      if @test_feature == "c" && @parameter[0] == "m"
        img = Imgrb::Image.new(file_path, :only_metadata)

        if @parameter[1] == "0"
          year = 2000
          month = 1
          day = 1
          hour = 12
          min = 34
          sec = 56
        elsif @parameter[1] == "7"
          year = 1970
          month = 1
          day = 1
          hour = 0
          min = 0
          sec = 0
        elsif @parameter[1] == "9"
          year = 1999
          month = 12
          day = 31
          hour = 23
          min = 59
          sec = 59
        end
        time_data = img.ancillary_chunks[:tIME][0].get_data
        assert_equal year, time_data.year
        assert_equal month, time_data.month
        assert_equal day, time_data.day
        assert_equal hour, time_data.hour
        assert_equal min, time_data.min
        assert_equal sec, time_data.sec
      end

    end

  end

  ##
  #Tests loading all valid png files in the test suite and performs some general
  #checks on reading header data.
  def test_load_valid_png_files

    each_file_with_updated_info do
      |file_path|

      if @test_feature != "x"

        #Reading valid png files should not raise any exception
        assert_nothing_raised do
          Imgrb::Image.new(file_path)
        end

        img = Imgrb::Image.new(file_path, :only_metadata)

        assert_equal 0, img.rows.size, "Only metadata loaded so no pixel data should be read."



        assert_equal @is_interlaced, img.header.interlaced?
        assert_equal @color_type_num, img.header.image_type
        assert_equal @bit_depth, img.header.bit_depth

        if @color_type_desc == "g"
          assert img.grayscale?
          assert !img.has_alpha? unless @test_feature == "t"
        end

        if @color_type_desc == "c" || @color_type_desc == "p"
          assert !img.grayscale?
          assert !img.has_alpha? unless @test_feature == "t"
        end

        if @color_type_num == 4
          assert img.grayscale?
          assert img.has_alpha?
        end

        if @color_type_num == 6
          assert !img.grayscale?
          assert img.has_alpha?
        end

        unless ["df", "dh", "ds"].include?(@parameter) || @test_feature == "s"
          assert_equal 32, img.width, "Incorrect width reported!"
          assert_equal 32, img.height, "Incorrect height reported!"
        end

        if @test_feature == "s"
          assert_equal img.width, img.height, "Image size should be square, but is not!"
          assert_equal @parameter.to_i, img.width, "Incorrect image size reported!"
        end
      end
    end
  end


  def test_add_text
    img = Imgrb::Image.new(10,10,[42,42,42])
    keyword = "Comment"
    keyword2 = "Copyright"
    text = "This is a test!"
    text2 = "© Foo Bar"
    img.add_text(keyword, text)
    img.add_text(keyword2, text2)
    2.times do |compression_level|
      png_str = save_png_to_string(img, compression_level)
      img_saved = Imgrb::Image.new(png_str, :from_string)

      assert [keyword.encode("ISO-8859-1"), keyword2.encode("ISO-8859-1")].include? img_saved.texts[0].keyword
      assert [keyword.encode("ISO-8859-1"), keyword2.encode("ISO-8859-1")].include? img_saved.texts[1].keyword
      assert [text.encode("ISO-8859-1"), text2.encode("ISO-8859-1")].include? img_saved.texts[0].text
      assert ([text.encode("ISO-8859-1"), text2.encode("ISO-8859-1")].include? img_saved.texts[1].text), "text: #{img_saved.texts[1].text} not present in the metadata"
    end

  end


  def test_add_compressed_text
    img = Imgrb::Image.new(10,10,[42,42,42])
    keyword = "Comment"
    keyword2 = "Copyright"
    text = "This is a test! Longer comment to be compressed. ABCDEFGhijklmnop"
    text2 = "© Foo Bar"
    img.add_text(keyword, text, true)
    img.add_text(keyword2, text2, true)
    2.times do |compression_level|
      png_str = save_png_to_string(img, compression_level)
      img_saved = Imgrb::Image.new(png_str, :from_string)

      assert [keyword.encode("ISO-8859-1"), keyword2.encode("ISO-8859-1")].include? img_saved.texts[0].keyword
      assert [keyword.encode("ISO-8859-1"), keyword2.encode("ISO-8859-1")].include? img_saved.texts[1].keyword
      assert [text.encode("ISO-8859-1"), text2.encode("ISO-8859-1")].include? img_saved.texts[0].text
      assert ([text.encode("ISO-8859-1"), text2.encode("ISO-8859-1")].include? img_saved.texts[1].text), "text: #{img_saved.texts[1].text} not present in the metadata"
    end

  end



  def test_add_international_text
    img = Imgrb::Image.new(10,10,[42,42,42])
    language = "en-us"
    language2 = "jp"
    keyword = "Software"
    keyword2 = "Software"
    translated_keyword = "Software"
    translated_keyword2 = "ソフトウェア"
    text = "This is a test! Longer comment with Unicode Emoji 💬 to be compressed. ABCDEFGhijklmnop"
    text2 = "Imgrb 💻"
    img.add_international_text(language, keyword, translated_keyword, text, true)
    img.add_international_text(language2, keyword2, translated_keyword2, text2, false)
    2.times do |compression_level|
      png_str = save_png_to_string(img, compression_level)
      img_saved = Imgrb::Image.new(png_str, :from_string)

      assert [keyword.encode("UTF-8"), keyword2.encode("UTF-8")].include? img_saved.texts[0].keyword
      assert [keyword.encode("UTF-8"), keyword2.encode("UTF-8")].include? img_saved.texts[1].keyword
      assert [text.encode("UTF-8"), text2.encode("UTF-8")].include? img_saved.texts[0].text
      assert ([text.encode("UTF-8"), text2.encode("UTF-8")].include? img_saved.texts[1].text), "text: #{img_saved.texts[1].text} not present in the metadata"
    end

  end


  def test_add_time
    img = Imgrb::Image.new(1,1,0)
    time_chunk = Imgrb::Chunks::ChunktIME.assemble
    time = time_chunk.get_data
    img.add_chunk(time_chunk)

    2.times do |compression_level|
      png_str = save_png_to_string(img, compression_level)
      img_saved = Imgrb::Image.new(png_str, :from_string)

      assert_equal time, img_saved.ancillary_chunks[:tIME][0].get_data
    end
  end

  def test_add_gamma
    img = Imgrb::Image.new(1,1,0)
    gamma_chunk = Imgrb::Chunks::ChunkgAMA.assemble(0.00042)
    img.add_chunk(gamma_chunk)

    2.times do |compression_level|
      png_str = save_png_to_string(img, compression_level)
      img_saved = Imgrb::Image.new(png_str, :from_string)

      assert_equal 0.00042, img_saved.ancillary_chunks[:gAMA][0].get_data
    end
  end


  def test_add_phys_dim
    img = Imgrb::Image.new(1,1,0)
    phys_chunk = Imgrb::Chunks::ChunkpHYs.assemble(1,2,0)
    img.add_chunk(phys_chunk)

    2.times do |compression_level|
      png_str = save_png_to_string(img, compression_level)
      img_saved = Imgrb::Image.new(png_str, :from_string)

      assert_equal 1, img_saved.ancillary_chunks[:pHYs][0].get_data[0]
      assert_equal 2, img_saved.ancillary_chunks[:pHYs][0].get_data[1]
      assert_equal 0, img_saved.ancillary_chunks[:pHYs][0].get_data[2]
    end
  end

  def test_add_offset
    img = Imgrb::Image.new(1,1,0)
    offset_chunk = Imgrb::Chunks::ChunkoFFs.assemble(-42,99,1)
    img.add_chunk(offset_chunk)

    2.times do |compression_level|
      png_str = save_png_to_string(img, compression_level)
      img_saved = Imgrb::Image.new(png_str, :from_string)

      assert_equal (-42), img_saved.ancillary_chunks[:oFFs][0].get_data[0]
      assert_equal 99, img_saved.ancillary_chunks[:oFFs][0].get_data[1]
      assert_equal 1, img_saved.ancillary_chunks[:oFFs][0].get_data[2]
    end
  end


  def test_add_background
    img = Imgrb::Image.new(1,1,0)
    background_chunk = Imgrb::Chunks::ChunkbKGD.assemble(0)
    img.add_chunk(background_chunk)

    img2 = Imgrb::Image.new(1,1,[20,20,20,0])
    background_chunk = Imgrb::Chunks::ChunkbKGD.assemble(0,5,100)
    img2.add_chunk(background_chunk)

    2.times do |compression_level|
      png_str = save_png_to_string(img, compression_level)
      img_saved = Imgrb::Image.new(png_str, :from_string)

      png_str = save_png_to_string(img2, compression_level)
      img_saved2 = Imgrb::Image.new(png_str, :from_string)

      assert_equal [0], img_saved.background_color
      assert_equal [0,5,100], img_saved2.background_color
    end
  end

  #TODO: FIX tRNS chunk behavior for non-indexed images (saving is fine, reading
  #is not)
  def test_add_transparency_chunk
    img = Imgrb::Image.new(41,41,0)
    transparency_chunk = Imgrb::Chunks::ChunktRNS.assemble(0,:indexed)
    img.add_chunk(transparency_chunk)

    png_str = save_png_to_string(img, 1)
    img_saved = Imgrb::Image.new(png_str, :from_string)

    assert img_saved.has_alpha?
  end

end
