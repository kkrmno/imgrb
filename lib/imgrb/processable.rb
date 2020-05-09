module Imgrb::BitmapModule
  ##
  #Mixin containing methods for processing bitmaps
  module Processable

    public
    ##
    #Transposes the pixel matrix making the rows columns. Mainly useful when
    #the Image instance is used as a convolution kernel.
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
    #The kernel must have either 1 channel or a number of channels equal to that of the image.
    #
    #Default border behavior is :zero, meaning padding with zeros. All options:
    #* +:zero+,        pad with zeros
    #* +:symmetric+,   pad by mirroring pixels past the border
    #* +:replicate+,   pad by extending image with closest border pixel
    #* +:circular+,    pad as if the image is periodic
    #
    def convolve(kernel, border_behavior = :zero)
      #TODO: Refactor
      if kernel.channels != self.channels && kernel.channels != 1
        raise ArgumentError, "Kernel must either be flat (i.e. 1 channel), or same depth as image (i.e. #{self.channels} channel(s))"
      end

      border_options = [:zero, :symmetric, :replicate, :circular]

      if !border_options.include?(border_behavior)
        raise ArgumentError, "Specified border behavior: '#{border_behavior}' not allowed. Must be one of: '#{border_options.join("', '")}'."
      end

      #Faster special case for grayscale images when convolving with 1D kernels
      #TODO: MAKE SPECIAL CASE APPLICABLE TO IMAGES WITH MULTIPLE CHANNELS!
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
    #Returns the horizontal and vertical components of the gradient of an image
    #using Gaussian derivatives (+sigma+ = +1+ by default).
    def gradient(sigma = 1, border_behavior = :replicate)
      #Separable convolution. Faster as 1D convolutions than 2D.
      kernel_h = Imgrb.gaussian(sigma)
      kernel_v = kernel_h.transpose
      kernel_h_deriv = Imgrb.gaussian_deriv(sigma)
      kernel_v_deriv = kernel_h_deriv.transpose

      x_deriv = self.convolve(kernel_h_deriv, border_behavior).convolve(kernel_v, border_behavior)
      y_deriv = self.convolve(kernel_v_deriv, border_behavior).convolve(kernel_h, border_behavior)

      return [x_deriv, y_deriv]
    end


    ##
    #Gaussian blur with specified sigma and border behavior.
    #For a full list of possible choices for border behavior, see the
    #documentation for #convolve.
    #Default:
    #* +sigma+ = +1+
    #* +border_behavior+ = +:replicate+
    def blur(sigma = 1, border_behavior = :replicate)
      #Separable convolution. Faster as 1D convolutions than 2D.
      kernel_h = Imgrb.gaussian(sigma)
      kernel_v = kernel_h.transpose

      return self.convolve(kernel_h, border_behavior).convolve(kernel_v, border_behavior)
    end

    ##
    #Rescales pixel values such that the maximal value of any channel is
    #+max_val+, and the minimum value is +min_val+. By default scales values to
    #the range [0, 1].
    def rescale(min_val = 0, max_val = 1)
      img = self.to_f
      self_min, self_max = img.bitmap.rows.flatten.minmax
      diff = max_val - min_val
      rescaled = (img - self_min)
      rescaled = rescaled * (diff/(self_max - self_min)) + min_val

      return rescaled
    end

    ##
    #Apply lambda to each channel, pixelwise (i.e. to each color component of
    #each pixel). The lambda should take a single value as input (the channel
    #value) and return a single value (the new channel value).
    def apply_lambda_flat(lambda)
      img = self.copy
      img.bitmap.rows.each do
        |r|
        r.collect!{|e| lambda[e]}
      end
      return img
    end


    ##
    #Apply lambda to each pixel. The lambda should take a single scalar if the
    #image has a single channel, otherwise an array of size equal to the number
    #of channels of the image, and should return a scalar/an array of size equal
    #to the number of desired channels in the transformed image (between 1 and 4)
    def apply_lambda(lambda)
      n_channels = Array(lambda[self[0,0]]).size
      img = Imgrb::Image.new(self.width, self.height, [0]*n_channels)
      self.each_with_coord do
        |val,x,y|
        rgb = lambda[val]
        img[y,x] = rgb
      end
      return img
    end

    ##
    #Applies cos to each channel, pixelwise.
    def cos
      apply_lambda_flat(->(x){Math.cos(x)})
    end

    ##
    #Applies sin to each channel, pixelwise.
    def sin
      apply_lambda_flat(->(x){Math.sin(x)})
    end

    ##
    #Applies tan to each channel, pixelwise.
    def tan
      apply_lambda_flat(->(x){Math.tan(x)})
    end

    ##
    #Applies acos to each channel, pixelwise.
    def acos
      apply_lambda_flat(->(x){Math.acos(x)})
    end

    ##
    #Applies asin to each channel, pixelwise.
    def asin
      apply_lambda_flat(->(x){Math.asin(x)})
    end

    ##
    #Applies atan to each channel, pixelwise.
    def atan
      apply_lambda_flat(->(x){Math.atan(x)})
    end

    ##
    #Applies atan2 to each grayscale pixel.
    #TODO: Handle images with several channels!
    def atan2(img_x)
      atan_img = Imgrb::Image.new(self.width, self.height, [0]*self.channels)

      if self.channels == 1
        self.each_with_coord do
          |val, x, y|
          atan_val = Math.atan2(val, img_x[y,x])
          atan_img[y,x] = atan_val
        end
      end

      return atan_img
    end

    private
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



  end
end
