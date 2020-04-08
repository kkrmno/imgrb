module Imgrb
  ##
  #This class represents images as a whole. An Image instance contains a header
  #and a bitmap. The header contains basic information about the image and the
  #bitmap contains the pixel data.
  class Image

    #TODO: Refactor!

    #include Imgrb::BitmapModule::Drawable
    include Enumerable
    attr_reader   :texts, :time, :header, :ancillary_chunks, :animation_frames, :bitmap
    attr_accessor :background_color

    #Construct an Image instance containing data from some image _img_ with
    #the options specified. Available options:
    #
    #
    #* :only_metadata, only load metadata
    #* :skip_ancillary. ignore ancillary chunks
    #* :skip_crc, to skip crc checks
    #
    #Ways to call new:
    #* new(img_0, ..., img_n), where each img_i is and Image instance with one channel, each img_i has the same size, and the number of input images determine the number of channels (max 4).
    #* new(width, height, color), where width and height are integers, and color is the color used to fill the image (number of channels determined by color.size)
    #* new(path), where path is a string pointing to a png, apng, or bmp file.
    #* new(string, :from_string => true), where string contains the bytes of an image.
    #* new(bitmap_rows, color_type, bit_depth), where bitmap_rows is an array of arrays (rows).
    #* new(hash), where hash contains options regarding :color, :width, :height, and :color_type
    def initialize(img = [[255, 255, 255, 255]], *options)

      #TODO: REFACTOR!

      #TODO?: #* :suggest_header [header], try to use _header_ as the header of the
      #  loaded image. Only loads the header from the image _img_ if
      #  _header_ seems to be incorrect. Using this option may speed
      #  up loading of multiple images of the same format (i.e. same width,
      #  height, bit depth etc.).

      raise ArgumentError, "Too many arguments (options.size + 1)!" if options.size > 3

      case img
      when Image
        max_channels = img.channels
        c_mode = Imgrb::PngConst::GRAYSCALE
        if options[0].is_a? Image
          c_mode = Imgrb::PngConst::GRAYSCALE_ALPHA
          max_channels = options[0].channels if options[0].channels > max_channels
          if options[1].is_a? Image
            c_mode = Imgrb::PngConst::TRUECOLOR
            max_channels = options[1].channels if options[1].channels > max_channels
            if options[2].is_a? Image
              c_mode = Imgrb::PngConst::TRUECOLOR_ALPHA
              max_channels = options[2].channels if options[2].channels > max_channels
            end
          end
        end

        if max_channels != 1
          raise ArgumentError, "Expected single channel image, got #{max_channels}"
        end

        @header = Imgrb::Headers::ImgrbHeader.new(img.width, img.height, 8, c_mode)
        color = [0]*@header.channels
        row = color*img.width
        blank_image = Array.new(img.height){ Array.new(row) }
        @bitmap = Imgrb::BitmapModule::Bitmap.new(self, blank_image)
        set_channel(0, img.rows)
        set_channel(1, options[0].rows) if channels > 1
        set_channel(2, options[1].rows) if channels > 2
        set_channel(3, options[2].rows) if channels > 3

      when Fixnum
        #TODO: Raise exception if too many options, e.g. Image.new(10,10,42,...,42,0)
        #(format should be width, height, color)
        width_ = img
        height_ = options[0]
        color = Array(options[1])
        if color.size == 1
          @header = Imgrb::Headers::ImgrbHeader.new(width_, height_, 8, Imgrb::PngConst::GRAYSCALE)
        elsif color.size == 2
          @header = Imgrb::Headers::ImgrbHeader.new(width_, height_, 8, Imgrb::PngConst::GRAYSCALE_ALPHA)
        elsif color.size == 3
          @header = Imgrb::Headers::ImgrbHeader.new(width_, height_, 8, Imgrb::PngConst::TRUECOLOR)
        elsif color.size == 4
          @header = Imgrb::Headers::ImgrbHeader.new(width_, height_, 8, Imgrb::PngConst::TRUECOLOR_ALPHA)
        else
          raise ArgumentError, "The filling color #{color} must have between 1 and 4 channels."
        end
        row = color*width_
        image = Array.new(height_){ Array.new(row) }
        @bitmap = Imgrb::BitmapModule::Bitmap.new(self, image)
      when String #Load from path or directly input image as string (option :from_string => true)
        @header = nil
        @bitmap = Imgrb::BitmapModule::Bitmap.new(self)
      when Array #Create image from pixel array
        if img.empty?
          raise ArgumentError, "The array must not be empty."
        end
        @bitmap = Imgrb::BitmapModule::Bitmap.new(self, img)
        options[0] = Imgrb::PngConst::TRUECOLOR_ALPHA if options.size == 0
        options[1] = 8 if options.size < 2
        bit_depth = options[1]
        if options[0] == Imgrb::PngConst::GRAYSCALE
          @header = Imgrb::Headers::ImgrbHeader.new(img[0].size, img.size, bit_depth, options[0])
        elsif options[0] == Imgrb::PngConst::GRAYSCALE_ALPHA
           @header = Imgrb::Headers::ImgrbHeader.new(img[0].size/2, img.size, 8, options[0])
        elsif options[0] == Imgrb::PngConst::TRUECOLOR
          @header = Imgrb::Headers::ImgrbHeader.new(img[0].size/3, img.size, 8, options[0])
        elsif options[0] == Imgrb::PngConst::TRUECOLOR_ALPHA
          @header = Imgrb::Headers::ImgrbHeader.new(img[0].size/4, img.size, 8, options[0])
        elsif options[0] == Imgrb::PngConst::INDEXED
          @header = Imgrb::Headers::ImgrbHeader.new(img[0].size, img.size, bit_depth, options[0])
        else
          raise ArgumentError, "Unknown image type option: #{options[0]}."
        end
      when Hash #Create image from hash
        @header, @bitmap = parse_image_hash(img)
      else
        raise ArgumentError, "The img argument has to be a string, hash or "\
                             "array, not #{img.class}."
      end

      parse_options(options)

      #PNG
      @background_color = []
      @ancillary_chunks = Hash.new {|h, k| h[k] = []}

      @palette = []
      @transparency_palette = []

      @png_image_stream = ""
      @chunks_found = []

      #Animations
      @current_frame = 0
      @previous_frame = self

      @apng_palette = nil
      @apng_transparency_palette = nil

      #Load image data if not generated by arguments earlier.
      if @header.nil?
        if @from_string
          load_from_string(img)
        else
          load(img)
        end
      end

      @animation_frames = []
      @animation_frames_cached = false

      #Needs testing for indexed apng images!
      if apng? && !@only_metadata
        # warn "This seems to be an apng file (animated png). This extension to "\
        #      "the png format is not supported. The data is treated as a "\
        #      "normal png file. Thus, only a single image will be loaded. This "\
        #      "is often the first frame of the animation, but may also be a "\
        #      "default image that has been included in the file "\
        #      "for decoders that do not handle the extension."
        @animation_frames = []
        n_frames, n_plays = @ancillary_chunks[:acTL][0].get_data
        @header = @header.to_apng_header(n_frames, n_plays, @bitmap)
        frame_control_chunks = @ancillary_chunks[:fcTL]
        frame_data_chunks = @ancillary_chunks[:fdAT]
        #If IDAT is first frame of animation
        if frame_control_chunks[0].pos == :after_IHDR || frame_control_chunks[0].pos == :after_PLTE
          @animation_frames[1..-1] = Imgrb::ApngMethods::create_frames(@header, frame_control_chunks[1..-1], frame_data_chunks, @apng_palette, @apng_transparency_palette)
          depalette
          @animation_frames[0] = [frame_control_chunks[0], Image.new(@bitmap.rows, @header.image_type)]
        else #If IDAT is not first frame of animation
          @animation_frames = Imgrb::ApngMethods::create_frames(@header, frame_control_chunks, frame_data_chunks, @apng_palette, @apng_transparency_palette)
        end

        @animation_frames_cached = true
      end

      depalette if @header.paletted?

    end

    ##
    #Retrieve list of ancillary_chunks. Also remove empty entries (bookkeeping).
    def ancillary_chunks
      @ancillary_chunks.delete_if do
        |key, value|
        value.size == 0
      end
    end

    ##
    #Is this an animated image?
    def animated?
      header.animated?
    end

    ##
    #Forward the animation one frame. Note that the first time this is called,
    #this may take a much longer time than normal (specifically for manually
    #generated animations, i.e. using push_frame etc.).
    def animate_step
      #FIXME: REFACTOR!
      #FIXME: CHECK IF CORRECT WHEN FIRST FRAME HAS DISPOSE OPERATION :previous
      if animated?
        if !@animation_frames_cached
          @animation_frames = []
          n_frames, n_plays = @ancillary_chunks[:acTL][0].get_data
          @header = @header.to_apng_header(n_frames, n_plays, @bitmap)
          frame_control_chunks = @ancillary_chunks[:fcTL]
          frame_data_chunks = @ancillary_chunks[:fdAT]
          #If IDAT is first frame of animation
          if frame_control_chunks[0].pos == :after_IHDR || frame_control_chunks[0].pos == :after_PLTE
            @animation_frames[1..-1] = Imgrb::ApngMethods::create_frames(@header, frame_control_chunks[1..-1], frame_data_chunks, @apng_palette, @apng_transparency_palette)
            depalette
            @animation_frames[0] = [frame_control_chunks[0], Image.new(@bitmap.rows, @header.image_type)]
          else #If IDAT is not first frame of animation
            @animation_frames = Imgrb::ApngMethods::create_frames(@header, frame_control_chunks, frame_data_chunks, @apng_palette, @apng_transparency_palette)
          end
          @animation_frames_cached = true
        end

        @current_frame += 1
        if @current_frame == header.number_of_frames
          reset_animation
        else

          previous_frame_data = @animation_frames[@current_frame-1]
          frame_data = @animation_frames[@current_frame]

          previous_frame_control = previous_frame_data[0]
          # previous_frame_image = previous_frame_data[1]

          frame_control = frame_data[0]
          frame_image   = frame_data[1]
          #Dispose of previous frame
          @bitmap.rows = Imgrb::ApngMethods::dispose_frame(self, @previous_frame, previous_frame_control)

          #Remember state before blending current frame, so that disposing of it next animation step is possible.
          @previous_frame = copy(frame_control.x_offset, frame_control.y_offset, frame_image.width, frame_image.height)
          #Blend in current frame
          # @bitmap.rows = Imgrb::ApngMethods::blend_frame(self, frame_image, frame_control)
          Imgrb::ApngMethods::blend_frame(self, frame_image, frame_control)
        end
      else
        raise Imgrb::Exceptions::AnimationError, "There is no animation data."
      end
      self
    end

    ##
    #Jumps an animation to its first frame.
    def reset_animation
      @current_frame = 0
      @bitmap.rows = @animation_frames[0][1].rows
      @previous_frame = self
      return self
    end

    ##
    #Jumps an animation to the given frame number.
    def jump_to_frame(frame_nr)
      if @current_frame > frame_nr
        reset_animation
      end

      prev_frame_nr = @current_frame
      while @current_frame < frame_nr
        animate_step
        raise IndexError, "frame_nr out of bounds" if prev_frame_nr > @current_frame
        prev_frame_nr = @current_frame
      end
      return self
    end

    ##
    #Returns an array of all text metadata associated with the image (Text objects)
    def texts
      if @ancillary_chunks
        (@ancillary_chunks[:tEXt] + @ancillary_chunks[:zTXt] + @ancillary_chunks[:iTXt]).collect{|chunk| chunk.get_data}
      end
    end

    ##
    #Add an ancillary chunk. The chunk_instance should be an instance
    #of a chunk object. See the documentation (and/or ancillary_chunk.rb) for
    #examples of ancillary chunks and how to define new ones.
    def add_chunk(chunk_instance)
      type = chunk_instance.type.to_sym
      @ancillary_chunks[type] << chunk_instance
    end

    ##
    #Convert associated bitmap to float
    def to_f
      f_image = Image.new(:color => [255]*channels, :width => width, :height => height, :color_type => header.image_type)
      rows.each_with_index do
        |row, r_ind|
        f_image[r_ind] = row.collect!.with_index{|c, c_i| c.to_f}
      end
      return f_image
    end

    ##
    #Convert associated bitmap to integer
    def to_i
      i_image = Image.new(:color => [255]*channels, :width => width, :height => height, :color_type => header.image_type)
      rows.each_with_index do
        |row, r_ind|
        i_image[r_ind] = row.collect!.with_index{|c, c_i| c.to_i}
      end
      return i_image
    end


    #FIXME: Refactor +,-,*,/,**

    ##
    #Pixelwise summation of two images (or image and scalar). Returns new sum-image. No value checking!
    #Max-value may be larger than allowed by bitdepth
    def +(image)
      if image.is_a?(Image)
        if (image.width*image.channels) == (width*channels) && image.height*image.channels == height*channels
          sum_image = Image.new(:color => [255]*channels, :width => width, :height => height, :color_type => header.image_type)
          @bitmap.rows.each_with_index do
            |row, index|
            other_row = image.bitmap.rows[index]
            sum_image[index] = row.collect.with_index{|c, c_i| c + other_row[c_i]}
          end
          return sum_image
        else
          raise Imgrb::Exceptions::ImageError, "Image dimensions do not agree "\
                                               "(either different width/height "\
                                               "or different number of color "\
                                               "channels)."
        end
      elsif image.is_a?(Numeric)
        self + (Image.new(:color => [image]*channels, :width => width, :height => height, :color_type => header.image_type))
      else
        raise TypeError, "can't convert #{image.class} into Image"
      end
    end

    ##
    #Pixelwise difference of two images (or image and scalar). Negative values allowed!
    #Returns new difference image
    def -(image)
      self + image * -1
    end

    ##
    #Unary minus (negates pixel values)
    def -@
      self * -1
    end

    ##
    #Unary plus (no effect). Returns a copy of self. For completeness.
    def +@
      self.copy
    end

    ##
    #Pixelwise multiplication of two images (or image and scalar). Returns new product image.
    #Max-value may exceed max possible for current bitdepth!
    def *(image)
      if image.is_a?(Image)
        if (image.width*image.channels) == (width*channels) && image.height*image.channels == height*channels
          prod_image = Image.new(:color => [255]*channels, :width => width, :height => height, :color_type => header.image_type)
          @bitmap.rows.each_with_index do
            |row, index|
            other_row = image.bitmap.rows[index]
            prod_image[index] = row.collect.with_index{|c, c_i| c * other_row[c_i]}
          end
          return prod_image
        else
          raise Imgrb::Exceptions::ImageError, "Image dimensions do not agree "\
                                               "(either different width/height "\
                                               "or different number of color "\
                                               "channels)."
        end
      elsif image.is_a?(Numeric)
        self * (Image.new(:color => [image]*channels, :width => width, :height => height, :color_type => header.image_type))
      else
        raise TypeError, "can't convert #{image.class} into Image"
      end
    end

    ##
    #Pixelwise exponentiation of two images (or image and scalar). Returns new result image.
    #Max-value may exceed possible for current bitdepth!
    def **(image)
      if image.is_a?(Image)
        if (image.width*image.channels) == (width*channels) && image.height*image.channels == height*channels
          prod_image = Image.new(:color => [255]*channels, :width => width, :height => height, :color_type => header.image_type)
          @bitmap.rows.each_with_index do
            |row, index|
            other_row = image.bitmap.rows[index]
            prod_image[index] = row.collect.with_index{|c, c_i| c ** other_row[c_i]}
          end
          return prod_image
        else
          raise Imgrb::Exceptions::ImageError, "Image dimensions do not agree "\
                                               "(either different width/height "\
                                               "or different number of color "\
                                               "channels)."
        end
      elsif image.is_a?(Numeric)
        self ** (Image.new(:color => [image]*channels, :width => width, :height => height, :color_type => header.image_type))
      else
        raise TypeError, "can't convert #{image.class} into Image"
      end
    end

    ##
    #Pixelwise division of two images (or image and scalar). Returns new result image.
    def /(image)
      self * image**(-1)
    end

    ##
    #Returns a new image where each channel contains the absolute values of the
    #corresponding channel in the old image.
    def abs
      abs_img = self.copy
      abs_img.bitmap.rows.each do
        |r|
        r.collect!{|e| e.abs}
      end
      return abs_img
    end


    ##
    #  image[row_idx]
    #returns the entire row specified by the index
    #  image[row_idx, col_idx]
    #returns the pixel at col_idx in row at row_idx
    #Note that the row and col are switched with respect to get_pixel, where column is given
    #first and row second (get_pixel(x,y))
    def [](y, x = nil)
      if x.nil?
        @bitmap.rows[y]
      else
        @bitmap.rows[y][x*header.channels..(x+1)*header.channels-1]
      end
    end

    ##
    #  image[row_idx, col_idx] = pixel
    #Note that the row and col are switched with respect to set_pixel, where column is given
    #first and row second (set_pixel(x,y,pixel))
    #Careful. Channels can be set to values outside bit depth.
    def []=(y, x = nil, v)
      v = Array(v)
      c = header.channels
      if x.nil?
        if v.size == @bitmap.rows[0].size
          @bitmap.rows[y] = v
          self
        else
          raise ArgumentError, "Wrong row size: #{v.size}. Expected "\
                             "#{@bitmap.rows[0].size}"
        end
      elsif v.size == c
        @bitmap.rows[y][x*c..(x+1)*c-1] = v
        self
      else
        raise ArgumentError, "Wrong pixel size: #{v.size}. Expected "\
                             "#{header.channels}"
      end
    end

    ##
    #Do something to each pixel
    def each &block
      Enumerator.new {
        |pixel|
        c = header.channels
        @bitmap.rows.each do
          |row|
          n_pixels = row.size/c
          n_pixels.times do
            |index|
            if  c == 1
              pixel << row[index*c]
            else
              pixel << row[index*c..(index+1)*c-1]
            end
          end
        end
        self
      }.each(&block)
    end

    ##
    #Do something to each row
    def each_row &block
      Enumerator.new {
        |row|
        rows.each do
          |r|
          row << r
        end
        self
      }.each(&block)
    end


    ##
    #Can be used to iterate over each frame of an animated image,
    #starting from the first frame.
    def each_frame &block
      Enumerator.new {
        |frame|
        old_frame_nr = @current_frame
        reset_animation
        if animated?
          start_frame = @current_frame
          frame << self.copy
          animate_step
          while start_frame != @current_frame
            frame << self.copy
            animate_step
          end
        else
          frame << self.copy
        end
        jump_to_frame(old_frame_nr)
      }.each(&block)
    end

    ##
    #Alias of each
    def each_pixel &block
      each(&block)
    end

    ##
    #Iterate over each pixel and index. Equivalent to each.with_index
    def each_pixel_with_index &block
      each.with_index(&block)
    end

    def transpose
      transpose_img = Imgrb::Image.new(height, width, [0]*channels)
      height.times do
        |y|
        width.times do
          |x|
          transpose_img.set_pixel(y, x, self.get_pixel(x, y))
        end
      end
      return transpose_img
    end

    ##
    #Convolves image with kernel (also an Image instance) and returns result as a new image.
    #The kernel must have either 1 channel or equal the number of channels as the image.
    #
    #Default border behavior is :zero, meaning padding with zeros. All options:
    #* +:zero+,        pad with zeros
    #* +:symmetric+,   pad by mirroring pixels past the border
    #* +:replicate+,   pad by extending image with closest border pixel
    #* +:circular+,    pad as if the image is periodic
    #
    #TODO: Refactor
    def convolve(kernel, border_behavior = :zero)
      if kernel.channels != self.channels && kernel.channels != 1
        raise ArgumentError, "Kernel must either be flat (i.e. 1 channel), or same depth as image (i.e. #{self.channels} channel(s))"
      end

      border_options = [:zero, :symmetric, :replicate, :circular]

      if !border_options.include?(border_behavior)
        raise ArgumentError, "Specified border behavior: '#{border_behavior}' not allowed. Must be one of: '#{border_options.join("', '")}'."
      end

      #Faster special case for grayscale images when convolving with 1D kernels
      if self.channels == 1
        if kernel.width == 1
          return convolve_col(kernel, border_behavior)
        elsif kernel.height == 1
          return convolve_row(kernel, border_behavior)
        end
      end

      conv_img = Imgrb::Image.new(self.width, self.height, [0]*self.channels)
      conv_img_rows = conv_img.bitmap.rows

      my_rows = self.bitmap.rows
      my_width = self.width
      my_width_less1 = self.width - 1
      my_height = self.height
      my_height_less1 = self.height-1
      num_my_channels = self.channels

      kernel_rows = kernel.bitmap.rows
      kernel_width = kernel.width
      kernel_width_less1 = kernel.width - 1
      kernel_height = kernel.height
      kernel_height_less1 = kernel.height - 1
      num_kernel_channels = kernel.channels

      kx_off = kernel.width/2
      ky_off = kernel.height/2
      x_range = ((-kx_off)...(self.width-kx_off))
      y_range = ((-ky_off)...(self.height-ky_off))

      num_my_channels.times do |c|

        if num_kernel_channels > 1
          #Faster than using entire bitmap of width x height x channels kernel,
          #unless kernel is very large (such that get_channel takes too long).
          kernel_rows = kernel.get_channel(c).bitmap.rows
        end

        y_range.each_with_index do |y_off_ky, y|
          x_range.each_with_index do |x_off_kx, x|

            #Conv at x, y:
            #===================================================================
            conv_value = 0

            kernel_height.times do |ky|
              y_offset = y_off_ky+ky

              #Handle border pixels (y):
              #Maybe use fetch with block instead.
              #-------------------------------------------------
              if y_offset < 0 || y_offset >= my_height
                if border_behavior == :zero
                  next
                elsif border_behavior == :symmetric
                  y_offset = get_symmetric_idx(y_offset, my_height_less1)
                elsif border_behavior == :replicate
                  y_offset = y_offset < 0 ? 0 : my_height_less1
                elsif border_behavior == :circular
                  y_offset = y_offset % my_height
                end
              end
              #-------------------------------------------------

              my_row = my_rows[y_offset]
              kernel_row = kernel_rows[kernel_height_less1 - ky]

              kernel_width.times do |kx|
                x_offset = x_off_kx+kx

                #Handle border pixels (x):
                #-----------------------------------------------
                if x_offset < 0 || x_offset >= my_width
                  if border_behavior == :zero
                    next
                  elsif border_behavior == :symmetric
                    x_offset = get_symmetric_idx(x_offset, my_width_less1)
                  elsif border_behavior == :replicate
                    x_offset = x_offset < 0 ? 0 : my_width_less1
                  elsif border_behavior == :circular
                    x_offset = x_offset % my_width
                  end
                end
                #-----------------------------------------------
                img_val = my_row[x_offset*num_my_channels + c]
                kernel_val = kernel_row[kernel_width_less1 - kx]

                conv_value = conv_value + kernel_val * img_val
              end
            end

            conv_img_rows[y][x*num_my_channels + c] = conv_value
            #===================================================================

          end
        end

      end

      return conv_img
    end

    ##
    #Returns an image instance containing a copy of the pixels specified.
    #Does not copy ancillary chunks etc. For apng, this means a copy is no
    #longer animated. Should maybe change this. Careful with unsafe chunks in
    #that case.
    def copy(col = 0, row = 0, width_ = width, height_ = height)
      rows = []
      height_.times do
        |y|
        rows << @bitmap.rows[row + y][col*header.channels..(col+width_)*header.channels-1]
      end

      Image.new(rows, @header.image_type, @header.bit_depth)
    end

    ##
    #More intuitive method for copying a part of an image (cf. +copy+).
    #Specify two coordinates, +x0+, +y0+, +x1+, +y1+, that identify the top left
    #corner and the bottom right corner of the window to be copied.
    #Returns the copied window as a new image.
    #NO CHECKING OF BOUNDS!
    def copy_window(x0, y0, x1, y1)
      #TODO: CHECK BOUNDS
      copy(x0, y0, x1-x0, y1-y0)
    end

    ##
    #Replace all pixels starting at +col+, +row+ by the pixels in the given image.
    #Modifies self!
    def paste(col, row, image)
      if header.channels != image.header.channels
        raise Exceptions::ImageError, "Trying to paste image with "\
                                      "#{image.header.channels} channels "\
                                      "onto image with #{header.channels} "\
                                      "channels."
      end

      rows = image.rows
      rows.size.times do
        |r|
        @bitmap.rows[row + r][col*header.channels..(rows[r].size + col*header.channels - 1)] = rows[r]
      end
      return self
    end

    ##
    #Alpha blends this image over the +background_image+ and returns a new
    #Image object resulting from the blend
    def alpha_over(background_image)
      background_image_copy = background_image.copy
      background_image_copy.alpha_under(self)
    end

    ##
    #Alpha compositing with another image using over operator.
    #  out_col   = col_fg*alpha_fg + col_bg*alpha_bg*(1-alpha_fg)
    #  out_alpha = alpha_fg + alpha_bg*(1-alpha_fg)
    #Assumes images of equal dimensions!
    #[CAREFUL!]
    #Currently modifies self! should possibly create a copy
    #(or at least rename to alpha_under!)
    #Use alpha_over if alpha blend should create a copy
    def alpha_under(foreground_image)
      #TODO: Refactor!
      #Add checks for alpha channel and matching number of channels!

      h = foreground_image.height
      w = foreground_image.width

      h.times do
        |row|

        w.times do
          |col|

          fg_alpha = foreground_image.get_pixel(col, row, channels-1)
          if fg_alpha == 0
            next
          elsif fg_alpha == 255
            self[row, col] = foreground_image[row, col]
          else

            fg_pixel = foreground_image[row, col]
            bg_pixel = self[row, col]

            if channels == 4
              bg_rc = bg_pixel[0]
              bg_gc = bg_pixel[1]
              bg_bc = bg_pixel[2]
              bg_ac = bg_pixel[3]/255.0

              fg_rc = fg_pixel[0]
              fg_gc = fg_pixel[1]
              fg_bc = fg_pixel[2]
              fg_ac = fg_pixel[3]/255.0


              r = fg_rc * fg_ac + bg_rc * bg_ac * (1 - fg_ac)
              g = fg_gc * fg_ac + bg_gc * bg_ac * (1 - fg_ac)
              b = fg_bc * fg_ac + bg_bc * bg_ac * (1 - fg_ac)
              a = (fg_ac + bg_ac * (1 - fg_ac))*255.0

              self[row, col] = [r.to_i, g.to_i, b.to_i, a.to_i]
            elsif channels == 2
              bg_gray = bg_pixel[0]
              bg_ac = bg_pixel[1]/255.0
              fg_gray = fg_pixel[0]
              fg_ac = fg_pixel[1]/255.0

              gray = fg_gray * fg_ac + bg_gray * bg_ac * (1 - fg_ac)
              alpha = (fg_ac + bg_ac * (1 - fg_ac))*255.0

              self[row, col] = [gray.to_i, alpha.to_i]
            else
              raise ArgumentError, "No alpha channel for alpha blending found."
            end
          end

        end
      end

      self

    end


    ##
    #Add text metadata to the image (if saved as png)
    #
    #The following keywords are predefined
    #(taken from the PNG (Portable Network Graphics) Specification,
    #Version 1.2):
    #* Title:            Short (one line) title or caption for image
    #* Author:           Name of image's creator
    #* Description:      Description of image (possibly long)
    #* Copyright:        Copyright notice
    #* Creation Time:    Time of original image creation
    #* Software:         Software used to create the image
    #* Disclaimer:       Legal disclaimer
    #* Warning:          Warning of nature of content
    #* Source:           Device used to create the image
    #* Comment:          Miscellaneous comment; conversion from GIF comment
    #
    #If no compression, creates a tEXt ancillary chunk.
    #If compression, creates a zTXt ancillary chunk.
    #Expects latin-1 encoded text (ISO-8859-1)
    #Use +add_international_text+ if UTF-8 is required.
    #
    def add_text(keyword, text, compressed = false)
      kw_length = keyword.bytes.to_a.size
      raise ArgumentError, "Keyword must be 1-79 bytes long" unless 1 <= kw_length && kw_length <= 79
      if(compressed)
        txt = PngMethods::deflate(text)
        data = keyword.bytes.to_a.pack("C*")
        data << "\x00\x00"
        data << txt
        add_chunk(Chunks::ChunkzTXt.new(data))
      else
        data = keyword.bytes.to_a.pack("C*")
        data << "\x00"
        data << text.bytes.to_a.pack("C*")
        add_chunk(Chunks::ChunktEXt.new(data))
      end
    end

    ##
    #Equivalent to
    #  add_text("Title", title)
    def add_title(title)
      add_text("Title", title)
    end

    ##
    #Equivalent to
    #  add_text("Comment", comment)
    def add_comment(comment)
      add_text("Comment", comment)
    end

    ##
    #Add international text chunk (iTXt)
    #Input:
    #* +language+ is a ISO-646 encoded string specifying the language
    #* +keyword+ is a Latin-1 (ISO-8859-1) encoded string specifying the keyword (see add_text)
    #* +translated_keyword+ is a UTF-8 encoded string containing a translation of the keyword into +language+
    #* +text+ is a UTF-8 encoded string containing the text written in +language+
    def add_international_text(language, keyword, translated_keyword, text, compressed = false)
      kw_length = keyword.bytes.to_a.size
      raise ArgumentError, "Keyword must be 1-79 bytes long" unless 1 <= kw_length && kw_length <= 79
      if(compressed)
        txt = PngMethods::deflate(text)
        null_byte_compr_str = "\x00\x01\x00"
      else
        txt = text
        null_byte_compr_str = "\x00\x00\x00"
      end

      data = keyword.bytes.to_a.pack("C*")
      data << null_byte_compr_str
      data << language.bytes.to_a.pack("C*")
      data << "\x00"
      data << translated_keyword.bytes.to_a.pack("C*")
      data << "\x00"
      data << txt.bytes.to_a.pack("C*")
      add_chunk(Chunks::ChunkiTXt.new(data))
    end


    ##
    #Channels start from 0. RGBA is stored as R at channel 0,
    #G at channel 1, B at channel 2, and A at channel 3.
    #Returns:
    #* a given channel as an Image, or
    #* a given row of a given channel as an array, or
    #* a given pixel of a given channel as an array/scalar
    def get_channel(c, col = nil, row = nil)
      if c < 0 || c >= channels
        raise ArgumentError, "Channel #{c} does not exist!"
      end

      if row.nil? && col.nil?
        chn = []
        @bitmap.rows.each do
          |row|
          chn << row.select.with_index{|e, i| i % channels == c}
        end
        return Image.new(chn,Imgrb::PngConst::GRAYSCALE)
      elsif col.nil?
        # if row > height - 1
          # raise IndexError, "Row #{row} is out of bounds!"
        # end
        @bitmap.rows.fetch(row).select.with_index{|e, i| i % channels == c}
      else
        #Raise own exception when necessary to give sensible error message
        #(since col is multiplied and added to).
        @bitmap.rows.fetch(row).fetch(col*channels+c){raise IndexError, "index #{col} outside of array bounds: #{-width}...#{width}"}
      end
    end

    ##
    #Sets channel +c+ to +new_channel+. The new channel is either
    #* a single channel image
    #* an array of arrays (rows)
    def set_channel(c, new_channel)
      new_channel = new_channel.rows if new_channel.is_a? Image
      if new_channel.size != height || new_channel[0].size != width
        raise ArgumentError, "Wrong size of new channel."
      elsif c < 0 || c >= channels
        raise ArgumentError, "Channel #{c} does not exist!"
      else

        #Use range together with step instead?
        @bitmap.rows.each.with_index do
          |row, row_i|
          channel_count = 0
          row.collect!.with_index do
            |e, i|
            if i % channels == c
              channel_count += 1
              new_channel[row_i][channel_count-1]
            else
              e
            end
          end
        end

      end
      return self
    end

    ##
    #Returns a new image instance converted to grayscale
    #
    #Uses: 0.299 * R + 0.587 * G + 0.114 * B
    def to_gray
      if channels == 1 || channels == 2
        return copy
      elsif channels == 3 || channels == 4
        r = get_channel(0)
        g = get_channel(1)
        b = get_channel(2)

        gray = (r*0.299 + g*0.587 + b*0.114).round!
        if channels == 4
          gray = Imgrb::Image.new(gray, get_channel(3))
        end

        return gray
      end

    end

    ##
    #Convert to rgb. Modifies self!
    def to_rgb
      @bitmap.to_rgb
      self
    end

    ##
    #Convert to rgba. Modifies self!
    def to_rgba
      @bitmap.to_rgba
      self
    end

    ##
    #Resize. Modifies self!
    def resize(x, y)
      header.resize(x, y, @bitmap)
      self
    end

    def move(x, y)
      @bitmap.move(x, y)
      self
    end

    ##
    #Return a copy of the rows.
    def rows
      @bitmap.rows.collect{|row| row.clone}
    end

    ##
    #Write rows. Careful! May set to rows incompatible with header.
    def rows=(rows)
      #Perform quick check if new rows seem reasonable
      if rows.size == @header.height && rows[0].size == @header.width*@header.channels
        @bitmap.rows = rows
      else
        raise Imgrb::Exceptions::ImageError, "New rows are of the wrong "\
                                             "dimensions (#{rows[0].size}, "\
                                            "#{rows.size} instead of "\
                                           "#{bm_width}, #{bm_height})."
      end
    end

    ##
    #Depalettes an indexed image
    def depalette
      if !@only_metadata
        if @header.paletted?
          @header = @header.to_png_header
          #Takes care of both the color palette and the transparency palette
          @bitmap.rows = Imgrb::PngMethods::depalette(@bitmap)
          # #May only have palette if color image so do not worry about grayscale.
          if @bitmap.transparency_palette != []
            @header.to_color_type(Imgrb::PngConst::TRUECOLOR_ALPHA, @bitmap)
          else
            @header.to_color_type(Imgrb::PngConst::TRUECOLOR, @bitmap)
          end
        elsif @bitmap.transparency_palette != []
          @bitmap.rows = Imgrb::PngMethods::use_transparency_color(@header, @bitmap)
          if @header.grayscale?
            @header.to_color_type(Imgrb::PngConst::GRAYSCALE_ALPHA, @bitmap)
          else
            @header.to_color_type(Imgrb::PngConst::TRUECOLOR_ALPHA, @bitmap)
          end
        end
      end
    end


    def inspect
      "#<Imgrb::Image:#{width}x#{height}, #{header.image_format}>"
    end


    ##
    #Rounds all values to integer. Modifies self!
    def round!
      @bitmap.rows.collect! do
        |row|
        row.collect! do
          |val|
          val.round
        end
      end
      self
    end

    ##
    #Rounds all values to integer.
    def round
      return self.copy.round!
    end

    ##
    #Takes ceiling of all values. Modifies self!
    def ceil!
      @bitmap.rows.collect! do
        |row|
        row.collect! do
          |val|
          val.ceil
        end
      end
      self
    end

    ##
    #Takes ceiling of all values.
    def ceil
      return self.copy.ceil!
    end

    ##
    #Takes floor of all values. Modifies self!
    def floor!
      @bitmap.rows.collect! do
        |row|
        row.collect! do
          |val|
          val.floor
        end
      end
      self
    end

    ##
    #Takes floor of all values.
    def floor
      return self.copy.floor!
    end

    def grayscale?
      @header.grayscale?
    end

    ##
    #Returns number of channels
    def channels
      @header.channels
    end

    def has_alpha?
      if @header.nil?
        return false
      else
        @header.has_alpha? || @bitmap.transparency_palette != []
      end
    end

    ##
    #Push an animation frame (apng) to the end of the frame sequence.
    #Converts image to an animated (if not animated already)
    def push_frame(img, x_offset = 0, y_offset = 0,
                   delay_num = 1, delay_den = 24,
                   dispose_op = :none, blend_op = :source)

      #TODO: CHECK VALID INPUT ARGUMENTS, E.G. DISPOSE_OP AND BLEND_OP
      #TODO: REFACTOR!

      if(img.size[0] > size[0] || img.size[1] > size[1])
        raise ArgumentError, "Pushed frame (size: #{img.size}) cannot be larger in size than the first frame (size: #{size})."
      elsif img.channels != channels
        raise ArgumentError, "Pushed frame has the wrong number of channels: #{img.channels} (expected #{channels})"
      end
      #FIXME: Should also check for paletted images


      has_actl_chunk = @ancillary_chunks[:acTL].size > 0
      #n_frames = @ancillary_chunks[:fcTL].size + 1
      if !has_actl_chunk
        #CONVERTING TO APNG!
        @animation_frames = []
        @ancillary_chunks[:acTL] = []
        n_frames = 2
        n_plays = 0
        data = [n_frames, n_plays].pack("N*")
        actl_chunk = Imgrb::Chunks::ChunkacTL.new(data)



        fctl_data0 = create_fcTL_chunk_data(0, self, 0, 0,
                                            delay_num, delay_den,
                                            :none, :source)
        fctl_data1 = create_fcTL_chunk_data(1, img, x_offset, y_offset,
                                            delay_num, delay_den,
                                            dispose_op, blend_op)
        fdat_data1 = create_fdAT_chunk_data(2, img)

        #First frame has fcTL before IDAT Chunk (meaning IDAT is first frame of
        #animation).
        fctl_chunk0 = Imgrb::Chunks::ChunkfcTL.new(fctl_data0, :after_IHDR)
        fctl_chunk1 = Imgrb::Chunks::ChunkfcTL.new(fctl_data1, :after_IDAT)
        fdat_chunk1 = Imgrb::Chunks::ChunkfdAT.new(fdat_data1, :after_IDAT)

        @ancillary_chunks[:acTL] = [actl_chunk]
        @ancillary_chunks[:fcTL].push(fctl_chunk0)
        @ancillary_chunks[:fcTL].push(fctl_chunk1)
        @ancillary_chunks[:fdAT].push(fdat_chunk1)


        @header = @header.to_png_header.to_apng_header(actl_chunk.get_data[0],
                                              actl_chunk.get_data[1], @bitmap)

      else
        current_seq_number = @ancillary_chunks[:fdAT].size*2

        fctl_data = create_fcTL_chunk_data(current_seq_number+1, img,
                                           x_offset, y_offset,
                                           delay_num, delay_den,
                                           dispose_op, blend_op)
        fdat_data = create_fdAT_chunk_data(current_seq_number+2, img)

        fctl_chunk = Imgrb::Chunks::ChunkfcTL.new(fctl_data, :after_IDAT)
        fdat_chunk = Imgrb::Chunks::ChunkfdAT.new(fdat_data, :after_IDAT)

        @ancillary_chunks[:fcTL].push(fctl_chunk)
        @ancillary_chunks[:fdAT].push(fdat_chunk)

        n_frames = @ancillary_chunks[:fcTL].size
        n_plays = 0
        data = [n_frames, n_plays].pack("N*")
        actl_chunk = Imgrb::Chunks::ChunkacTL.new(data)
        @ancillary_chunks[:acTL] = [actl_chunk]

        @header = @header.to_apng_header(actl_chunk.get_data[0],
                                         actl_chunk.get_data[1], @bitmap)

      end

      return self
    end

    ##
    #Removes the last frame from an animation sequence (apng).
    def pop_frame
      if @ancillary_chunks[:fcTL].size > 0 && @ancillary_chunks[:fdAT].size > 0
        frame_control = @ancillary_chunks[:fcTL].pop
        frame_data = @ancillary_chunks[:fdAT].pop


        n_frames = @ancillary_chunks[:fcTL].size
        n_plays = 0
        data = [n_frames, n_plays].pack("N*")
        actl_chunk = Imgrb::Chunks::ChunkacTL.new(data)
        @ancillary_chunks[:acTL] = [actl_chunk]

        @header = @header.to_apng_header(actl_chunk.get_data[0],
                                         actl_chunk.get_data[1], @bitmap)

        #FIXME:
        #SHOULD PROBABLY RETURN THE DATA AS AN ARRAY OF AN IMAGE OBJECT AND SOME
        #FRAME DATA INSTEAD!
        return [frame_data, frame_control]
      else
        return nil
      end
    end


    ##
    #Get pixel at coordinate +x+, +y+ using get_pixel(x,y). Note that +y+ is 0
    #at the top of the image and increases as the rows descend horizontally.
    #The +x+ coordinate increases from left to right.
    #
    #Alternatively get_pixel(x,y,c) gives the value of channel +c+ at +x+, +y+.
    def get_pixel(x, y, *chan)
      raise ArgumentError, "wrong number of arguments (given #{chan.size + 2}, expected 2 or 3)." if chan.size > 1

      if chan.size == 1
        r_channel = chan[0]
      else
        r_channel = :all
      end

      is_outside, err_str = out_of_bounds?(x, y, r_channel)
      raise IndexError, err_str if is_outside

      c = channels
      if c == 1
        val = @bitmap.rows[y][x]
      else
        val = @bitmap.rows[y][x*c..x*c+c-1]
        val = val[r_channel] if r_channel != :all
      end

      val
    end

    ##
    #Set pixel at coordinate +x+, +y+ to +pxl+. Note that +y+ is 0 at the top of the image
    #and increases as the rows descend horizontally. The +x+ coordinate increases
    #from left to right. Here +pxl+ depends on the number of channels. If grayscale
    #without alpha, pxl is a single integer. If there are more than one channel,
    #pxl is an array with as many elements as there are channels (array of size
    #1 is also acceptable for grayscale images)
    #
    #Alternatively set_pixel(x, y, c, value) sets pnly the value of a specific
    #channel +c+ at coordinate (+x+, +y+) to +value+.
    def set_pixel(x, y, *chan, pxl)
      raise ArgumentError, "wrong number of arguments (given #{chan.size + 3}, expected 3 or 4)." if chan.size > 1

      pxl = Array(pxl)

      if chan.size == 1
        r_channel = chan[0]
        raise ArgumentError, "wrong pixel size (given #{pxl.size}, expected 1)." if pxl.size != 1
      else
        r_channel = :all #No specified channel
        raise ArgumentError, "wrong pixel size (given #{pxl.size}, expected #{channels})." if pxl.size != channels
      end

      is_outside, err_str = out_of_bounds?(x, y, r_channel)
      raise IndexError, err_str if is_outside


      if r_channel == :all
        channels.times do
          |i|
          @bitmap.rows[y][x*channels+i] = pxl[i]
        end
      else
        @bitmap.rows[y][x*channels+r_channel] = pxl[0]
      end

      if pxl.size == 1
        pxl[0]
      else
        pxl
      end
      #For png. Affects which ancillary chunks can be copied over.
      #header.making_critical_changes!
    end

    ##
    #Save image to filename. The format is determined by the file-ending, i.e.
    #"img_name.png" to save a png/apng file and "img_name.bmp" for a bmp file.
    #Compression level only applies to png.
    #Compression level 0 is fastest.
    #Currently, compression level 1 tries to convert to indexed color png and
    #tries out several filters. Compression level 0 does not try converting to
    #indexed color and only uses filter 0 (this may change in future, and more
    #options for how to compress may be introduced).
    #
    #If :skip_ancillary is given as an option, no ancillary chunks will be
    #saved, thus stripping all metadata.
    def save(filename, compression_level = 0, *options)
      name_arr = filename.split(".")
      if name_arr.size > 1
        file_type = name_arr[-1].downcase
        file_name = name_arr[0...-1].join(".")

        raise ArgumentError, "No file name!" if file_name.length == 0

      else
        raise ArgumentError, "File name must contain a '.'"
      end

      if file_type == "png"
        #Currently saving apng as paletted is a problem (the fdAT chunks need to
        #be dealt with correctly). Therefore prevent paletting apngs. FIXME!
        compression_level = 0 if apng?
        save_png(filename, compression_level, *options)
      else
        save_bmp(filename)
      end

    end

    ##
    #Returns the image width in pixels
    def width
      return -1 if @header.nil?
      @header.width
    end

    ##
    #Returns the image height in pixels
    def height
      return -1 if @header.nil?
      @header.height
    end

    # def initialize_copy(source)
    #   super
    # end

    ##
    #Returns width, height, and number of channels.
    def size
      return [@header.width, @header.height, @header.channels]
    end

    ##
    #Removes alpha channel. Modifies self!
    def remove_alpha!
      if has_alpha?
        @bitmap.rows.collect! do
          |row|
          row.delete_if.with_index{|v,i| (i+1)%channels == 0}
        end
        if channels == 4
          header.to_color_type(Imgrb::PngConst::TRUECOLOR, @bitmap)
        elsif channels == 2
          header.to_color_type(Imgrb::PngConst::GRAYSCALE, @bitmap)
        else
          raise Imgrb::Exceptions::ImageError, "Error removing alpha."
        end

      end
      self
    end

    ##
    #Remove?
    #
    #Returns a flat array of values.
    #
    #Problems with grayscale?
    #Remove in favor of rows and get_channel (add get_channels)?
    def to_blob(x = 0, y = 0, w = -1, h = -1)
      if w == -1 && h == -1
        w = width-x
        h = height-y
      elsif w < 0 || h < 0
        raise ArgumentError, "Blob width and height must be >= 0"
      elsif w > width || h > height
        raise ArgumentError, "Blob width and height must be <= image "\
                             "width and height respectively."
      end

      x %= width
      y %= height

      if x+w > width || y+h > height
        raise IndexError, "Coordinates out of bounds #{[x + w, y + h]}"
      end

      if has_alpha?
        w = w*4
        x = x*4
      else
        w = w*3
        x = x*3
      end

      dup_rows = rows
      sblob = []
      h.times do
        |hh|
        w.times do
          |ww|
          sblob << dup_rows[hh+y][ww+x]
        end
      end
      return sblob
    end

    def to_blob_without_alpha(x = 0, y = 0, w = -1, h = -1)
      return to_blob(x, y, w, h) unless has_alpha?
      to_blob(x, y, w, h).collect.with_index do
        |p, i|
        if i%4 == 3
          nil
        else
          p
        end
      end.compact
    end

    ##
    #Prints a report. Maybe just return a string instead?
    def report
      puts "===================REPORT==================="
      if @header.image_format == :bmp
        puts "+BMP HEADER+"
        puts "FORMAT: BMP"
        puts "FILE SIZE: " + @header.file_size.to_s
        puts "DATA OFFSET: " + @header.data_offset.to_s
        puts "+DIB HEADER+"
        puts "DIB SIZE: " + @header.image_type.to_s
        puts "DIB HEADER NAME: " + @header.dib_type
        puts "WIDTH: " + width.to_s
        puts "HEIGHT: " + height.to_s
        puts "NUMBER OF COLOR PLANES: " + @header.color_planes.to_s
        puts "NUMBER OF BITS PER PIXEL: " + @header.bit_depth.to_s
        puts "COMPRESSION METHOD: " + @header.compression_method.to_s
        puts "IMAGE SIZE: " + @header.image_size.to_s
        puts "PADDED ROW SIZE: " + BmpMethods::find_multiple_of_4(width*3).to_s
        puts "HORIZONTAL RESOLUTION (PIXELS/METER): #{@header.horizontal_res}"
        puts "VERTICAL RESOLUTION (PIXELS/METER): " + @header.vertical_res.to_s
        puts "NUMBER OF COLORS IN PALETTE: " + @header.colors.to_s
        puts "IMPORTANT COLORS: " + @header.important_colors.to_s
        puts "+OTHER+"
        puts "PADDING: #{(BmpMethods::find_multiple_of_4(width*3)-width*3)}"
      elsif @header.image_format == :png
        puts "+PNG HEADER+"
        puts "FORMAT: PNG"
        puts "WIDTH: " + width.to_s
        puts "HEIGHT: " + height.to_s
        puts "BIT DEPTH: " + @header.bit_depth.to_s
        puts "NUMBER OF CHANNELS: " + @header.channels.to_s
        puts "COLOR TYPE: " + @header.color_type.capitalize
        puts "COMPRESSION: " +  @header.compression_method.to_s
        puts "FILTER METHOD: " + @header.filter_method.to_s
        #puts "FILTER TYPE PER ROW: " + @filters.to_s
        puts "INTERLACE: " + @header.interlace_method.to_s
        #puts "PALETTE: " + @header.palette.to_s
        if @bitmap.transparency_palette != []
          puts "TRANSPARENCY PALETTE: #{@bitmap.transparency_palette}"
        end
        puts "+OTHER+"
        puts "COMPUTED FILE SIZE: " + @header.to_bmp_header.file_size.to_s
        # if @chunks[:texts].length > 0
        #   puts
        #   puts "------------------------------------------"
        #   puts "TEXTUAL INFORMATION: "
        #   @chunks[:texts].each do
        #     |t|
        #     t.get_data.report
        #   end
        #   puts "------------------------------------------"
        #   puts
        # end
        # if @time != nil
        #   puts "LAST MODIFICATION TIME: " + @time.to_s
        # end
        # if @gamma != -1
        #   puts "GAMMA: " + @gamma.to_s
        # end
        # if @dimensions != []
        #   puts
        #   puts "------------------------------------------"
        #   puts "PHYSICAL DIMENSIONS: "
        #   if @dimensions[2] == 1
        #     puts "UNIT: METER"
        #   else
        #     puts "UNIT: UNKNOWN"
        #   end
        #   puts "PIXELS PER UNIT, X AXIS: " + @dimensions[0].to_s
        #   puts "PIXELS PER UNIT, Y AXIS: " + @dimensions[1].to_s
        #   puts "------------------------------------------"
        #   puts
        # end

        # if @offset != []
        #   puts
        #   puts "------------------------------------------"
        #   puts "IMAGE OFFSET: "
        #   if @offset[2] == 0
        #     puts "UNIT: PIXELS"
        #   else @offset[2] == 1
        #     puts "UNIT: MICRONS"
        #   end

        #   puts "X-OFFSET: " + @offset[0].to_s
        #   puts "Y-OFFSET: " + @offset[1].to_s
        #   puts "------------------------------------------"
        #   puts
        # end

        if @background_color != nil
          puts
          puts "------------------------------------------"
          puts "BACKGROUND COLOR: "
          p @background_color
          puts "------------------------------------------"
          puts
        end

        unknown_ancillary = []
        @ancillary_chunks.values.each do
          |chunks|
          chunks.each do
            |chunk|
            unknown_ancillary << chunk if !PngMethods::known_ancillary_chunk?(chunk)
          end
        end

        if unknown_ancillary != []
          puts
          puts "------------------------------------------"
          puts "UNKNOWN CHUNKS ENCOUNTERED: #{unknown_ancillary.size}"
          c_strings = []
          unknown_ancillary.each do
            |c|
            c_strings << [c.type, c.data]
          end
          #c_string = c_string[0..-3]
          c_strings.each.with_index do
            |pair,ind|
            p (ind+1).to_s + ". " + pair[0] + ": " + pair[1].unpack("C*").to_s
            puts
            puts
          end
          puts "------------------------------------------"
          puts
        end

        #print "NUMBER OF COLORS: "
        if !@only_metadata
          puts "PALETTABLE?"
          #now = Time.now
          puts PngMethods::palettable?(self, 3000)
          #puts "NUMBER OF COLORS: "
          #puts count_colors(@bitmap.rows, has_alpha?, 256)
          #print "TIME TO COUNT: "
          #puts Time.now - now
        end

        puts "CHUNKS (IN ORDER):"
        p @chunks_found
      else
        puts "UNKNOWN FORMAT"
      end

      puts "===============END REPORT==================="
    end










    private
    #Load a bmp or png image, where img is its  location.
    def load(img)
      image = IO.binread(img)

      extract_info(image)
    end

    def load_from_string(img)
      extract_info(img)
    end

    def apng?
      @ancillary_chunks.key?(:acTL) &&
      @ancillary_chunks[:acTL].size == 1 &&
      (@ancillary_chunks[:acTL][0].pos == :after_IHDR ||
      @ancillary_chunks[:acTL][0].pos == :after_PLTE)
    end

    def parse_image_hash(options)
      color = options[:color]
      width = options[:width]
      height = options[:height]
      color_type = options[:color_type]

      if !color_type
        if has_alpha?
          color_type = Imgrb::PngConst::TRUECOLOR_ALPHA
        else
          color_type = Imgrb::PngConst::TRUECOLOR
        end
      end
      header = Imgrb::Headers::ImgrbHeader.new(width, height, 8, color_type)

      row = color*width
      image = Array.new(height){ Array.new(row) }
      bitmap = Imgrb::BitmapModule::Bitmap.new(self, image)

      [header, bitmap]
    end

    def parse_options(opt)
      if opt.size > 0 && opt[0].is_a?(Hash)
        options = opt[0]

        @show_filters = options[:show_filters]
        @unfiltered = options[:unfiltered]
        @only_metadata = options[:only_metadata]
        @memory_over_speed = options[:memory_over_speed]
        @skip_ancillary = options[:skip_ancillary]
        @skip_crc = options[:skip_crc]
        @from_string = options[:from_string]
      else
        @only_metadata = !!opt.index(:only_metadata)
        @skip_ancillary = !!opt.index(:skip_ancillary)
        @skip_crc = !!opt.index(:skip_crc)
      end
    end


    def out_of_bounds?(x, y, c = :all)
      outside = false
      error_str = ""

      error_str = "Coordinate x = #{x} too large for image. Maximum #{width - 1}" if x > width - 1
      error_str = "Coordinate x = #{x} must be >= 0." if x < 0
      error_str = "Coordinate y = #{y} too large for image. Maximum #{height - 1}" if y > height - 1
      error_str = "Coordinate y = #{y} must be >= 0." if y < 0

      unless c == :all
        error_str = "Channel c = #{c} must be >= 0" if c < 0
        error_str = "Channel c = #{c} must be < #{channels} (#channels)" if c >= channels
      end

      outside = true if error_str.size > 0
      return [outside, error_str]
    end


    #TODO: Move to ChunkfcTL.assemble ?
    def create_fcTL_chunk_data(seq_num, img, x_offset, y_offset,
                               delay_num, delay_den, dispose_op, blend_op)
      data_4byte = [seq_num, img.width, img.height, x_offset, y_offset].pack("N*")
      data_2byte = [delay_num, delay_den].pack("n*")

      dispose_op_byte = 0 #:none
      if dispose_op == :background
        dispose_op_byte = 1
      elsif dispose_op == :previous
        dispose_op_byte = 2
      end

      blend_op_byte = 0 #source
      blend_op_byte = 1 if blend_op == :over

      data_1byte = [dispose_op_byte, blend_op_byte].pack("C*")

      data = data_4byte + data_2byte + data_1byte
    end


    #TODO: Move to ChunkfdAT.assemble ?
    def create_fdAT_chunk_data(seq_num, img)
      png_parts = Imgrb::PngMethods.generate_png(img, img.header.to_png_header, 0, true)
      idat_bytes = png_parts[6]
                                #SKIP THE IDAT CHUNK NAME + OLD LENGTH INFO
      data = [seq_num].pack("N")+idat_bytes[8..-1]
    end


    #======================================================================
    #Convolution helpers. Hacky stuff to improve performance for 1D kernels
    #======================================================================

    ##
    #Convolve self with 1D kernel (row). The kernel should have height or width 1.
    def convolve_row(kernel_1d_img, border_behavior)
      conv_img = Imgrb::Image.new(self.width, self.height, 0)

      kernel_values = kernel_1d_img.bitmap.rows.flatten.reverse

      my_rows = self.bitmap.rows
      conv_img_rows = conv_img.bitmap.rows

      kx_off = kernel_values.size/2

      my_width_less1 = self.width - 1
      my_width = self.width
      kernel_size = kernel_values.size

      x_range = ((-kx_off)...(self.width-kx_off))
      y_range = (0...self.height)

      y_range.each do |y|
        my_row = my_rows[y]
        x_range.each do |x|

          #===================================================================
          #Ugly, but fast (relatively speaking)
          conv_value = 0
          idx = 0
          while idx < kernel_size
            x_off = x + idx
            replicate_idx = check_border_condition(x_off, my_width_less1)

            #If inside border, replicate_idx is 1
            if replicate_idx == 1
              conv_value += kernel_values[idx] * my_row[x_off]
            #Do nothing if padding with 0
            #elsif border_behavior == :zero
              #conv_value += 0
            elsif border_behavior == :replicate
              conv_value += kernel_values[idx] * my_row[replicate_idx]
            elsif border_behavior == :symmetric
              x_off = get_symmetric_idx(x_off, my_width_less1)
              conv_value += kernel_values[idx] * my_row[x_off]
            elsif border_behavior == :circular
              conv_value += kernel_values[idx] * my_row[x_off%my_width]
            end

            idx += 1
          end

          conv_img_rows[y][x+kx_off] = conv_value
          #===================================================================
        end
      end


      return conv_img
    end


    ##
    #Convolve self with 1D kernel (col). The kernel should have height or width 1
    #
    def convolve_col(kernel_1d_img, border_behavior)
      conv_img = Imgrb::Image.new(self.width, self.height, 0)

      kernel_values = kernel_1d_img.bitmap.rows.flatten.reverse

      my_rows = self.bitmap.rows
      conv_img_rows = conv_img.bitmap.rows

      ky_off = kernel_values.size/2

      my_height = self.height
      my_height_less1 = self.height - 1
      kernel_size = kernel_values.size

      x_range = (0...self.width)
      y_range = ((-ky_off)...(self.height-ky_off))

      replicate_idx = nil

      y_range.each do |y|
        y_ky_off = y+ky_off
        x_range.each do |x|

          #===================================================================
          #Ugly, but fast (relatively speaking)
          conv_value = 0
          idx = 0
          while idx < kernel_size
            y_off = y + idx

            replicate_idx = check_border_condition(y_off, my_height_less1)

            #If inside border, replicate_idx is 1
            if replicate_idx == 1
              conv_value += kernel_values[idx] * my_rows[y_off][x]
            #Do nothing if padding with 0
            #elsif border_behavior == :zero
              #conv_value += 0
            elsif border_behavior == :replicate
              conv_value += kernel_values[idx] * my_rows[replicate_idx][x]
            elsif border_behavior == :symmetric
              y_off = get_symmetric_idx(y_off, my_height_less1)
              conv_value += kernel_values[idx] * my_rows[y_off][x]
            elsif border_behavior == :circular
              conv_value += kernel_values[idx] * my_rows[y_off%my_height][x]
            end

            idx += 1
          end

          conv_img_rows[y_ky_off][x] = conv_value
          #===================================================================
        end
      end


      return conv_img
    end

    ##
    #Returns
    #* 1 if inside border
    #* 0 if offset_idx is too small
    #* -1 if offset_idx is too large
    def check_border_condition(offset_idx, max_idx)
      if offset_idx < 0
        replicate_idx = 0
      elsif offset_idx > max_idx
        replicate_idx = -1
      else
        replicate_idx = 1
      end
      replicate_idx
    end

    ##
    #Perform mirror reflections until the position is inside bounds.
    #The loop is necessary to take care of values that are very far out of bounds.
    def get_symmetric_idx(idx, max_idx)
      until idx >= 0 && idx <= max_idx
        idx = idx < 0 ? idx.abs : (2*max_idx - idx)
      end
      return idx
    end


    #End of convolution helpers
    #=========================================================================


    def save_png(filename, compression_level = 0, *options)
      if @bitmap.empty?
        raise Imgrb::Exceptions::ImageError, "No image data read"
      end
      if options.index(:skip_ancillary)
        skip_ancillary = true
      else
        skip_ancillary = false
      end
      #When saving as palette alpha channel not retained at the moment.
      unless compression_level > 0 && PngMethods::try_palette_save(self, filename, compression_level)
        PngMethods::save_png(self, @header.to_png_header,
                             filename, compression_level, skip_ancillary)
      end
    end

    #Saves bmp
    def save_bmp(filename)
      if @header.channels < 3
        raise Imgrb::Exceptions::ImageError, "Can only save color images as bmp."
      end
      #if @header.channels != 3 || @header.bit_depth != 8
       # report
        #raise Imgrb::Exceptions::ImageError, "Can only save 24-bit color bmp. Not #{@header.channels}-channel #{@header.bit_depth}-bit images."
      #end
      @background_color ||= [255, 255, 255] #Default bg color when saving bmp.
      if @bitmap.empty?
        raise Imgrb::Exceptions::ImageError, "No image data read"
      end
      s_image = []
      s_width = -1

      File.open(filename, 'wb') do
        |output|
        bmp = "BM"
        s_image = @bitmap.to_bmp_format

        bmp << @header.to_bmp_header.print_header

        s_image.each do
          |row|
          bmp << row.pack("C*")
        end
        output.print bmp
      end
    end

    #Side effects: @header is set to the image header
    #              @bitmap now contains the pixel data
    def extract_info(image)
      if image[0..1].unpack("C*") == [66, 77] #BMP SIGNATURE
        #BMP Header
        image = image.unpack("C*")

        @header = BmpMethods::extract_bmp_header(image)
        bpp = @header.bit_depth

        width_factor = 1
        width_factor = 3 if bpp == 24

        if bpp != 24
          #Only partial support for non 24-bit bmp images.
          bmp_palette = image[54..(4*(@color_palette)+53)] #Broken now.
          bmp_palette = bmp_palette.reject.with_index {|x, i| (i+1)%4 == 0}
        end
        if !@only_metadata
          @bitmap.read_bmp_pixels(image[@header.data_offset..-1], width, bpp)
        end
      elsif image[0..7].unpack("C*") == [137,80,78,71,13,10,26,10] #PNG SIGNATURE
        #PNG Header
        #Extract all chunks from the png file
        chunks = PngMethods::read_png(image, @skip_ancillary, @skip_crc)
        previous_crit_chunk = ""
        chunks.each do
          |ch|
          @chunks_found << ch.type
          previous_crit_chunk = interpret_chunk(ch, previous_crit_chunk)
        end
        #After the chunks have been interpreted to extract relevant information
        #we may throw them away.
        #@chunks = nil

      else
        raise Imgrb::Exceptions::ImageError, "Unknown image format."
      end

      #After the file has been processed we may throw away the bytes.
      #@image = nil
    end

    def check_legal_position_of_chunk(previous_crit_chunk, chunk)
      if previous_crit_chunk == "IEND"
        raise Imgrb::Exceptions::ChunkError, "#{chunk.type} found after IEND."
      end
      case chunk
      when "IHDR"
        unless previous_crit_chunk == ""
          raise Imgrb::Exceptions::ChunkError, "IHDR at position #{chunk.pos} "\
                                               "is not first."
        end
      when "PLTE"
        unless previous_crit_chunk == "IHDR"
          raise Imgrb::Exceptions::ChunkError, "Missing IHDR chunk or "\
                                               "PLTE not before IDAT or "\
                                               "multiple instances of PLTE."
        end

        if @header.image_type == 0 || @header.image_type == 4
          raise Imgrb::Exceptions::ChunkError, "PLTE chunk found in a png of "\
                                               "type #{@header.color_type}."
        end
      when "IDAT"
        unless previous_crit_chunk == "PLTE" ||
               previous_crit_chunk == "IDAT" ||
               (previous_crit_chunk == "IHDR" && !@header.paletted?)

          if @header.paletted?
            raise Imgrb::Exceptions::ChunkError, "PLTE chunk missing"
          end
          raise Imgrb::Exceptions::ChunkError, "IDAT not after PLTE or IDAT"
        end
      when "IEND"
        unless previous_crit_chunk == "IDAT"
          raise Imgrb::Exceptions::ChunkError, "No image data IDAT"
        end
      when "cHRM"
        unless previous_crit_chunk == "IHDR"
          warn "Ancillary chunk cHRM not before PLTE and IDAT. "\
               "Ignoring cHRM chunk."
        end
      when "oFFs"
        unless previous_crit_chunk != "IDAT"
          warn "Ancillary chunk oFFs not before IDAT. Ignoring oFFs chunk."
        end
      end
    end

    #All known critical chunks objects are thrown away after the data has been
    #extracted.
    def interpret_critical_chunk(chunk)
      case chunk.type
      when "IHDR"
        @header = chunk.get_data
      when "PLTE"
        @bitmap.palette = chunk.get_data
        @apng_palette = chunk
      when "IDAT"
        @png_image_stream << chunk.get_data if !@only_metadata
      when "IEND"
        if !@only_metadata
          # @bitmap.rows = get_image_data(@png_image_stream)
          @filters = @bitmap.read_png_pixels(@header, @png_image_stream)
          @png_image_stream = ""
        end
      else
        raise Imgrb::Exceptions::ChunkError, "Unknown critical chunk: "\
                                             "#{chunk.type}."
      end
    end

    #In most cases we keep the chunk as an object. A few special cases
    #exist where the chunk object is discarded after the data has been
    #extracted. These cases are: bKGD, tRNS. TODO: Make consistent!
    def interpret_ancillary_chunk(chunk)
      #case chunk.type
      # when "tEXt", "zTXt", "iTXt"
      #   @chunks[:texts] << chunk
      # when "tIME"
      #   @chunks[:time] = chunk
      # #when "gAMA"
      #  # @chunks[:gamma] = chunk
      # when "pHYs"
      #   @chunks[:dimensions] = chunk
      # when "oFFs"
      #   @chunks[:offset] = chunk
      #if PngMethods::known_ancillary_chunk?(chunk)
        if chunk.type == "bKGD"
          bgc = chunk.get_data
          if @header.grayscale?
            @background_color = PngMethods::read_grayscale(@header, [[bgc]])[0]
          elsif @header.paletted?
            bg_col_bitmap = BitmapModule::Bitmap.new(self, [[bgc]])
            bg_col_bitmap.palette = @bitmap.palette
            @background_color = PngMethods::depalette(bg_col_bitmap)[0]
            #Background color should not have alpha
            #(possible side effect of depalette).
            #@background_color.pop if has_alpha?
          else
            @background_color = bgc
          end
          #May confuse things, since background color may be changed for the
          #image without affecting this chunk (at the moment at least).
          #@ancillary_chunks[:known] << chunk
        elsif chunk.type == "tRNS"
          if @header.has_alpha?
            warn "tRNS chunk not expected in "\
                 "png of this type (#{@header.color_type})"
          end
          @apng_transparency_palette = chunk
          if @png_image_stream == ""
            png_trans_palette = chunk.get_data
            #If color type is 0 or 2 each sample in the transparency palette
            #is two bytes. One sample for type 0, three samples for type 2.
            if @header.image_type == 0
              png_trans_palette = [bytes_to_int(png_trans_palette)]
            end

            if @header.image_type == 2
              png_trans_palette = [bytes_to_int(png_trans_palette[0..1]),
                                   bytes_to_int(png_trans_palette[2..3]),
                                   bytes_to_int(png_trans_palette[4..5])]
            end

            @bitmap.transparency_palette = png_trans_palette
            @has_alpha = true
          else
            warn "tRNS chunk appears after first IDAT chunk. No alpha used."
          end
          #At the moment the tRNS ancillary chunk is not stored.
        else
          @ancillary_chunks[chunk.type.to_sym] << chunk
        end
      #else
       # @ancillary_chunks[:unknown] << chunk
      #end
    end

    #Takes an array of chunk objects and extracts information.
    def interpret_chunk(chunk, previous_crit_chunk)
      if !@only_metadata
        check_legal_position_of_chunk(previous_crit_chunk, chunk.type)
      end

      if chunk.critical?

        previous_crit_chunk = chunk.type

        interpret_critical_chunk(chunk)
        #Catch errors if @only_metadata ?

      else
        interpret_ancillary_chunk(chunk)
      end

      return previous_crit_chunk
    end

    def count_colors(image, has_alpha, max)
      palette_hash = Hash.new
      bytes_per_color = 3
      bytes_per_color += 1 if has_alpha
      catch(:max_exceeded) do
        image.each do
          |row|
          row.each_slice(bytes_per_color) do
            |pixel|
            if palette_hash.size > max
              throw :max_exceeded
            end
            unless palette_hash.has_key? pixel[0..2]
              palette_hash[pixel[0..2]] = palette_hash.size
            end
          end
        end
      end
      return palette_hash.size
    end

    def bytes_to_int(bytes)
      bit_string = ""
      bytes.each do
        |b|
        bs = b.to_s(2)
        bs = "0"*(8 - bs.length) << bs
        bit_string << bs
      end
      bit_string.to_i(2)
    end

  end
end
