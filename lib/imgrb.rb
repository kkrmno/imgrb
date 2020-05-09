##
#A pure ruby library for reading and writing images.
#Reads png grayscale, truecolor, 1-, 2-, 4- and 8-bit indexed-color,
#grayscale with alpha and truecolor with alpha
#and 24-bit bmp files. Saves 24-bit bmp files and truecolor with alpha
#png files.
#
#Also handles reading and writing apng files.
#
#== Recogniced  ancillary chunks:
#* tRNS, transparency palette
#* tEXt, uncompressed textual metadata
#* iTXt, international compressed or uncompressed textual metadata
#* zTXt, compressed textual metadata
#* tIME, time of last image modification
#* gAMA, image gamma
#* oFFs, specifies the image offset (e.g. for positioning in print)
#* pHYs, physical pixel dimensions, i.e. number of pixels per unit
#* bKGD, preferred background color
#* etc.
#
#Example usage:
#   require 'imgrb'
#
#   image = Imgrb::Image.new("img.png")
#   p image.texts #Prints all text metadata
#   image.save("img_new.png")
module Imgrb

  # def self.load(file_name)
  #   file = IO.binread(file_name)
  #   type = Imgrb::Shared::file_type(file)
  #   if type == :png
  #   elsif type == :bmp
  #   else
  #     raise ImageError, "Unknown file type of #{file_name}."
  #   end
  # end



  ##
  #Register user defined png chunks
  def self.register_chunks(*klasses)
    Chunks.register_chunks(*klasses)
  end

  ##
  #Return all registered chunks
  def self.registered_chunks
    Chunks.registered_chunks
  end

  #PNG constants (color types, interlace methods, ...)
  module PngConst
    GRAYSCALE       = 0
    TRUECOLOR       = 2
    INDEXED         = 3
    GRAYSCALE_ALPHA = 4
    TRUECOLOR_ALPHA = 6

    NOT_INTERLACED = 0
    ADAM7          = 1

    #"\x89PNG\r\n\x1A\n"
    PNG_START = [137, 80, 78, 71, 13, 10, 26, 10].pack("C*").freeze
    #"\x00\x00\x00\x00IEND\xAEB`\x82"
    PNG_END = [0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130].pack("C*").freeze
  end
end

require 'zlib'

require 'imgrb/bitmap'
require 'imgrb/processable'
require 'imgrb/exceptions'
#require 'imgrb/misc'
#require 'imgrb/drawable'
require 'imgrb/filters'
require 'imgrb/shared'
require 'imgrb/version'
require 'imgrb/text'
require 'imgrb/image'
require 'imgrb/apng_methods'
require 'imgrb/png_methods'
require 'imgrb/bmp_methods'

require 'imgrb/headers/minimal_header'
require 'imgrb/headers/png_header'
require 'imgrb/headers/apng_header'
require 'imgrb/headers/bmp_header'
require 'imgrb/headers/imgrb_header'

require 'imgrb/chunks/chunk_register'
require 'imgrb/chunks/private'
require 'imgrb/chunks/public'
require 'imgrb/chunks/safe'
require 'imgrb/chunks/unsafe'
require 'imgrb/chunks/critical'
require 'imgrb/chunks/ancillary'
require 'imgrb/chunks/abstract_chunk'
require 'imgrb/chunks/critical_chunks'
require 'imgrb/chunks/ancillary_chunks'
