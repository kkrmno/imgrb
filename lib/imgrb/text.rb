module Imgrb
  ##
  #This class represents textual data along with any keywords read from chunks
  #that deal with text (i.e. tEXt, zTXt, and iTXt)
  class Text
    attr_reader :language, :translated_keyword
    def initialize(keyword, text, compressed = false, international = false,
                   language = "", translated_keyword = "")
      @keyword = keyword
      @text = text
      @compressed = compressed
      @international = international
      @language = language.force_encoding("646")
      @translated_keyword = translated_keyword.force_encoding("UTF-8")
    end

    ##
    #Returns true if the text chunk is international, false otherwise
    def international?
      @international
    end

    ##
    #Decompresses (if necessary) and forces correct encoding
    def text
      txt = @text
      if @compressed
        txt = PngMethods::inflate(@text)
      end

      if @international
        txt.force_encoding("UTF-8")
      else
        txt.force_encoding("ISO-8859-1")
      end
    end

    def keyword
      @keyword.force_encoding("ISO-8859-1")
    end

    ##
    #Prints formatted keyword and text
    def report
      if @language == "" && @translated_keyword == ""
        puts @keyword + ": " + text
      else
        puts @language
        puts @keyword + ", " + @translated_keyword + ": " + text
      end
    end
  end
end
