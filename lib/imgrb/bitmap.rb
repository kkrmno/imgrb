module Imgrb
  #Contains classes concerned with handling the bitmap present in Image instances
  module BitmapModule

    ##
    #This class contains the matrix of pixels that represents the image data.
    #
    #[SHOULD PROBABLY ONLY BE USED INTERNALLY]
    #
    #The class also has methods that manipulate this data. Each instance of the
    #image class has one bitmap instance, which contains the images pixel data.
    class Bitmap

      #Returns the pixel data as an array of rows containing the bytes that make
      #up the image.
      attr_reader :rows

      #Currently should only be used internally. May change in the future.
      attr_accessor :palette, :transparency_palette #:nodoc:

      ##
      #Takes a reference to the Image instance that contains this Bitmap, as
      #well as an array of arrays (representing the rows) containing pixel data.
      def initialize(image, rows = [])
        @image = image
        @rows = rows

        @palette = []
        @transparency_palette = []
      end

      def rows=(rows) #:nodoc:
        #Perform quick check if new rows seem reasonable
        #if rows.size == bm_height && rows[0].size == bm_width
          @rows = rows
        #else
         # raise Imgrb::Exceptions::ImageError, "New rows are of the wrong "\
          #                                     "dimensions (#{rows[0].size}, "\
           #                                    "#{rows.size} instead of "\
            #                                   "#{bm_width}, #{bm_height})."
        #end
      end

      ##
      #Is the bitmap empty?
      def empty?
        @rows.empty?
      end

      ##
      #Is there an alpha channel?
      def has_alpha?
        @image.has_alpha?
      end

      def to_rgb #:nodoc:
        channels = @image.header.channels
        if channels == 3
          return self
        elsif channels < 3
          to_add = 3 - channels
          add_channels(@rows, to_add)
        elsif channels == 4
          @image.remove_alpha!
        else
          raise Imgrb::Exceptions::ImageError, "Unable to convert from "\
                                               "#{channels} channels to 3."
        end
        @image.header.to_color_type(Imgrb::PngConst::TRUECOLOR, self)
      end

      def to_rgba #:nodoc:
        channels = @image.header.channels
        if channels == 4
          return self
        elsif channels < 4
          to_add = 4 - channels
          add_channels(@rows, to_add)
          @image.header.to_color_type(Imgrb::PngConst::TRUECOLOR_ALPHA, self)
          @image.set_channel(3, [[255]*@image.width]*@image.height)
        else
          raise Imgrb::Exceptions::ImageError, "Unable to convert from "\
                                               "#{channels} channels to 3."
        end
        self
      end

      private
      def bm_height
        @rows.size
      end

      def bm_width
        if empty?
          0
        else
          @rows[0].size
        end
      end

      #Add a channel with value as specified by channel_rows.
      #Can probably be done faster. Change complicated expression
      #with each_slice, zip, flatten etc.
      def add_channels(channel_rows = [[0]*@image.header.width]*@image.header.height, n_channels)
        new_rows = []
        @rows.each_with_index do
          |r, i|
          new_rows << r.each_slice(@image.channels).to_a.zip(channel_rows[i].collect {|e| [e]*n_channels}).flatten
        end
        @rows = new_rows
      end



      #Padded width of a row _without_ alpha (since this
      #is only used for bmp files).
      def padded_width
        w = bm_width
        w -= w / 4 if @image.has_alpha?
        Imgrb::BmpMethods::find_multiple_of_4(w)
      end

      public
      # def get_pixel(x, y)
      #   if @image.grayscale?
      #     c = 1
      #     @rows[y][x]
      #   else
      #     c = 3
      #     c = 4 if @image.has_alpha?
      #     @rows[y][x*c..x*c+c-1]
      #   end
      # end

      #Pads with 0s at / removes from bottom and right
      def resize(x, y)
        width = x*@image.channels
        height = y
        @rows += [[]]*(height - @rows.size) if @rows.size < height
        @rows = @rows[0..height]
        @rows.collect! do
          |r|
          if r.size < width
            r + [0]*(width - r.size) #r.concat instead?
          else
            r[0...width]
          end
        end
      end

      def move(x_step, y_step)
        x_step = x_step*@image.channels
        if x_step > 0
          @rows.collect! do
            |r|
            clipped_width = r.size - x_step
            clipped_row = r[0..(clipped_width-1)]
            r[x_step..-1] = clipped_row
            r[0...x_step] = [0]*(x_step)
            r
          end
        elsif x_step < 0
          @rows.collect! do
            |r|
            clipped_width = r.size + x_step
            clipped_row = r[-x_step..-1]
            r[0..clipped_width] = clipped_row
            r[clipped_width+1..-1] = [0]*(-x_step-1)
            r
          end
        end

        if y_step > 0
          width = @rows[0].size
          @rows[y_step..-1] = @rows[0...-y_step]
          @rows[0...y_step] = [[0]*width]*y_step
        elsif y_step < 0
          y_step -= 1
          width = @rows[0].size
          @rows[0..y_step] = @rows[-y_step-1..-1]
          @rows[y_step..-1] = [[0]*width]*(-y_step)
        end
      end



      #FIXME: This method should read in the pixel data from a bmp file and
      #order it in a sensible way in the @rows. This modifies the object
      #directly, even though no !.
      def read_bmp_pixels(data, width, bpp)
        padded_row_size = Imgrb::BmpMethods::find_multiple_of_4(width * 3)
        padding = padded_row_size - width * 3  #3 bytes per pixel
        @rows = data.each_slice(padded_row_size).to_a
        @rows.collect! {|row| row[0...-padding]} if padding > 0
        #Only 24-bit bmp supported at the moment.
        #@rows = Imgrb::BmpMethods::depalette(self) if bpp != 24
        @rows = Imgrb::BmpMethods::fix_bmp_reverse_pixel(@rows)
      end

      #Poorly named!
      #Remove header argument, use @image.header in body?
      #Modifies @rows as side-effect.
      def read_png_pixels(header, data)
        #TODO: Refactor
        filters, @rows = Imgrb::PngMethods::inflate_n_bit(header, data,
                                                               header.bit_depth)
        #At the moment inflate_n_bit defilters and inflates n-bit, non-interlaced
        #images for n < 8, but only inflates for n >= 8.
        # if header.bit_depth == 8 || header.bit_depth == 16 || header.bit_depth == 1 || header.bit_depth == 2 || header.bit_depth == 4
          if header.interlaced?
            #Defilter each pass and then combine.
            defiltered_passes = []
            #Defiltering passes

            @rows.each_with_index do

              |image, pass|
              h = image.size
              #If the pass is not empty
              if h > 0
                w = image[0].size / header.channels

                #Creating "fake" header for the pass.
                pass_header = Imgrb::Headers::PngHeader.new(w, h,
                                                      header.bit_depth,
                                                      header.compression_method,
                                                      header.image_type,
                                                      header.filter_method,
                                                      header.interlace_method)
                defiltered_passes << Imgrb::PngMethods::defilter(pass_header,
                                                                 image,
                                                                 filters[pass],
                                                                 false)
              #If the pass IS empty
              else
                defiltered_passes << []
              end

            end

            # if header.bit_depth == 16
            #   p "BITDEPTH 16"
            #   defiltered_passes.each do
            #     |pass|
            #     Imgrb::PngMethods::merge_bytes(pass)
            #     Imgrb::PngMethods::normalize_image_data(pass)
            #   end
            # end

            #Combine the passes to the final image.
            if header.bit_depth == 16
              defiltered_passes.each do
                |pass|
                Imgrb::PngMethods::merge_bytes(pass)
              end
            end
            @rows = Imgrb::PngMethods::combine_passes(header, defiltered_passes)

          #Because non-interlaced 1-, 2-, 4-bit images have already been defiltered.
          elsif header.bit_depth == 8 || header.bit_depth == 16
            @rows = Imgrb::PngMethods::defilter(header, @rows, filters,
                                                     false)
            #Remove show_filters argument? I.e     this ^
            Imgrb::PngMethods::merge_bytes(@rows) if header.bit_depth == 16
          end
        # end


        #Normalize pixel array so that it only contains values between 0 and 255
        # if header.bit_depth == 16
        #   Imgrb::PngMethods::normalize_image_data(@rows)
        # end

        # if header.grayscale? && header.bit_depth < 8
        #   #Rescales to 8-bit values, probably should not do this (or should be optional)
        #   @rows = Imgrb::PngMethods::read_grayscale(header, @rows)
        # end
        filters
      end


      ##
      #This method returns a pixel matrix where
      #the pixel data is ordered as in a bmp file.
      def to_bmp_format
        bmp_formatted = []
        last = bm_height - 1
        @rows.each_index do   #Bottleneck
          |ind|
          bmp_formatted << Array.new(padded_width, 0)
          row = @rows[last-ind]
          offsetter = 0
          row.each_with_index do
            |p,i|
            pixel_index = i + offsetter
            if pixel_index % 3 == 0
              pixel_index += 2
            elsif pixel_index % 3 == 2
              pixel_index -= 2
            end
            if @image.has_alpha? && (i+1)%4 == 0
              #DONT WRITE ALPHA TO BMP
              #Use background_color for alpha if existent. TODO: CHECK THIS!
              if @image.background_color != nil && @image.background_color != []
                bmp_formatted[ind][pixel_index-3] += ((1.0-(p/255.0))*(@image.background_color[0] - bmp_formatted[ind][pixel_index-3])).to_i
                bmp_formatted[ind][pixel_index-4] += ((1.0-(p/255.0))*(@image.background_color[1] - bmp_formatted[ind][pixel_index-4])).to_i
                bmp_formatted[ind][pixel_index-5] += ((1.0-(p/255.0))*(@image.background_color[2] - bmp_formatted[ind][pixel_index-5])).to_i
              end
              offsetter -= 1
            else
              bmp_formatted[ind][pixel_index] = p
            end
          end
        end
        bmp_formatted
      end

    end


  end
end
