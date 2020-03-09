module Imgrb::Headers
  ##
  #Header for animated png files
  class ApngHeader < PngHeader
    attr_reader :filter_method, :interlace_method, :default_image,
                :number_of_frames, :number_of_plays
    def initialize(width, height, bit_depth, compression_method, image_type,
                   filter_method, interlace_method, number_of_frames,
                   number_of_plays, default_image)

      super(width, height, bit_depth, compression_method, image_type,
            filter_method, interlace_method)
      @default_image = default_image
      @number_of_frames = number_of_frames
      @number_of_plays = number_of_plays
    end

    def image_format
      :apng
    end

    def animated?
      true
    end
  end
end
