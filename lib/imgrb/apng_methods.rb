module Imgrb

  #General methods used internally when reading/writing png files.
  module ApngMethods #:nodoc:

    private
    def self.create_frames(header, frame_control_chunks, frame_data_chunks, palette_chunk, transparency_chunk)
      sorted_chunks = (frame_control_chunks + frame_data_chunks)
      sorted_chunks.sort! {|x,y| x.sequence_number <=> y.sequence_number}


      #After each frame control chunk, any subsequent fdAT chunks belong
      #to the same deflated data until a new fcTL chunk is arrived at.
      frame_header = [sorted_chunks[0]]
      mock_header = [frame_header[0].to_png_header(header)]
      mock_image_data = []
      dat = sorted_chunks[1].get_data
      (sorted_chunks.size-2).times do
        |i|
        c = sorted_chunks[i+2]
        #Concatenate fdAT to complete stream
        if c.type == "fdAT"
          dat << c.get_data
        elsif c.type == "fcTL"
          mock_image_data << dat
          dat = ""
          frame_header << c
          mock_header << c.to_png_header(header)
        end
      end

      mock_image_data << dat unless dat == ""


      #Will not work with indexed images
      mock_images = []
      mock_header.each.with_index do
        |header, i|
        mock_image = ""
        img = mock_image_data[i]
        crc = [Zlib.crc32("IDAT" + img, 0)].pack('N')
        mock_idat = [img.size].pack('N') << "IDAT" << img << crc


        mock_image << PngConst::PNG_START.dup
        mock_image << header.print_header
        mock_image << palette_chunk.get_raw unless palette_chunk.nil?
        mock_image << transparency_chunk.get_raw unless transparency_chunk.nil?
        mock_image << mock_idat
        mock_image << PngConst::PNG_END.dup
        mock_images << mock_image
      end

      frames = []

      mock_images.each.with_index do
        |img, i|
        frame = Imgrb::Image.new(img, :from_string => true)
        frame.header.to_png_header
        frames << [frame_header[i], frame]
      end

      return frames
    end

    def self.dispose_frame(image, previous_frame, previous_frame_control)
      x_offset = previous_frame_control.x_offset
      y_offset = previous_frame_control.y_offset
      operation = previous_frame_control.dispose_operation
      if    operation == :none #APNG_DISPOSE_OP_NONE
        return image.rows
      elsif operation == :background #APNG_DISPOSE_OP_BACKGROUND
        #SHOULD ONLY OVERWRITE THOSE PIXELS AFFECTED BY THE PREVIOUS BLENDOP
        bg_w = previous_frame.width
        bg_h = previous_frame.height
        bg_color_type = previous_frame.header.image_type
        bg_color = [0, 0, 0, 0]
        background_image = Imgrb::Image.new(:color => bg_color, :width => bg_w, :height => bg_h, :color_type => bg_color_type)
        temp_image = Imgrb::Image.new(image.rows)
        temp_image.paste(x_offset, y_offset, background_image)
        return temp_image.rows
      elsif operation == :previous #APNG_DISPOSE_OP_PREVIOUS
        temp_image = Imgrb::Image.new(image.rows)
        temp_image.paste(x_offset, y_offset, previous_frame)
        return temp_image.rows
      else
        raise Imgrb::Exceptions::AnimationError, "Unknown dispose operation for "\
                                                 "apng: #{operation}."
      end
    end

    ##
    #Modifies image as side effect
    def self.blend_frame(image, next_frame, control)
      operation = control.blend_operation
      x_offset = control.x_offset
      y_offset = control.y_offset

      if operation == :source #APNG_BLEND_OP_SOURCE
        image.paste(x_offset, y_offset, next_frame)
      elsif operation == :over #APNG_BLEND_OP_OVER

        w = next_frame.width
        h = next_frame.height

        cut_out_bg = image.copy(x_offset, y_offset, w, h)
        cut_out_bg.alpha_under(next_frame)

        image.paste(x_offset, y_offset, cut_out_bg)
        return
      else
        raise Imgrb::Exceptions::AnimationError, "Unknown blend operation for "\
                                                 "apng: #{operation}."
      end
    end

  end
end
