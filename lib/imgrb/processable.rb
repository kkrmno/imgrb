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
    #Dilate image using the given +structuring_element+ (SE). For a flat SE, use
    #an image containing only 0s and -Float::INFINITY.
    def dilate(structuring_element)
      #TODO: Optimize!
      dilate_helper(self, structuring_element, true)
    end


    ##
    #Erode image using the given +structuring_element+ (SE). For a flat SE, use
    #an image containing only 0s and -Float::INFINITY.
    def erode(structuring_element)
      #TODO: Optimize!
      return -dilate_helper((-self), structuring_element, false)
    end

    ##
    #Open image using the given +structuring_element+ (SE). For a flat SE, use
    #an image containing only 0s and -Float::INFINITY
    def open(structuring_element)
      #TODO: Optimize!
      erode(structuring_element).dilate(structuring_element)
    end

    ##
    #Open image using the given +structuring_element+ (SE). For a flat SE, use
    #an image containing only 0s and -Float::INFINITY
    def close(structuring_element)
      #TODO: Optimize!
      dilate(structuring_element).erode(structuring_element)
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


    ##
    #Resizes image by given scale and method. By default, the method used is
    #bilinear interpolation. Other options are: :nearest (for nearest neighbor)
    #
    #Note that scaling an image down may cause aliasing.
    #Example usage:
    #* img.resize(scale_xy)
    #* img.resize(scale_xy, method)
    #* img.resize(scale_x, scale_y)
    #* img.resize(scale_x, scale_y, method)
    def resize(*scale, method)
      #TODO: Implement antialiasing.
      if scale.size == 0
        scale = [method, method]
        method = :bilinear
      elsif scale.size == 1
        scale = [scale[0], method]
        method = :bilinear
      elsif scale.size != 2
        raise ArgumentError, "wrong number of arguments (given #{scale.size}, expected 1..2)"
      end

      raise ArgumentError, "scale must be larger than 0." if scale.include? 0


      if method == :bilinear
        return bilinear(scale[0], scale[1])
      elsif method == :nearest
        return nearest_neighbor(scale[0], scale[1])
      else
        raise ArgumentError, "unknown method: #{method}"
      end
    end


    ##
    #Compares against another image of equal size and returns a new image which,
    #for each channel, is 1 where this image is greater than the other, 0
    #otherwise
    def is_greater(img_to_compare)
      return is_compared(img_to_compare, :greater)
    end

    ##
    #Compares against another image of equal size and returns a new image which,
    #for each channel, is 1 where this image is lesser than the other, 0
    #otherwise
    def is_lesser(img_to_compare)
      return is_compared(img_to_compare, :lesser)
    end

    ##
    #Compares against another image of equal size and returns a new image which,
    #for each channel, is 1 where this image is equal to the other, 0
    #otherwise
    def is_equal(img_to_compare)
      return is_compared(img_to_compare, :equal)
    end















    private

    def is_compared(comp_image, relation)
      if comp_image.is_a?(Numeric)
        comp_image = Imgrb::Image.new(self.width, self.height, [comp_image]*self.channels)
      elsif comp_image.is_a?(Array)
        comp_image = Imgrb::Image.new(self.width, self.height, comp_image)
      end
      if self.size != comp_image.size
        raise ArgumentError, "images must be of equal size (given #{comp_image.size}, expected #{self.size})"
      end

      comp_img_channels = self.each_channel.with_index.collect do |channel_img, c|
        is_compared_gray(channel_img, comp_image.get_channel(c), relation)
      end

      return Imgrb::Image.new(*comp_img_channels)
    end

    def is_compared_gray(image, comp_image, relation)
      res_image = Imgrb::Image.new(self.width, self.height, 0)
      image.each_with_coord do |val, x, y|
        if relation == :greater
          holds = val > comp_image[y][x]
        elsif relation == :lesser
          holds = val < comp_image[y][x]
        elsif relation == :equal
          holds = val == comp_image[y][x]
        end
        res_image[y][x] = 1 if holds
      end
      return res_image
    end

    ##
    #Dilate image using the given +structuring_element+ (SE). For a flat SE, use
    #an image containing only 0s and -Float::INFINITY.
    def dilate_helper(image, structuring_element, reflect = true)
      #TODO: Optimize!
      if image.channels == 1
        dilated_image = dilate_gray(image, structuring_element, reflect)
      else
        dilated_channels = image.each_channel.collect do |channel_img|
          dilate_gray(channel_img, structuring_element, reflect)
        end
        dilated_image = Imgrb::Image.new(*dilated_channels)
      end
      return dilated_image
    end

    def dilate_gray(image, structuring_element, reflect)
      #TODO: Optimize!
      dilated_image = Imgrb::Image.new(image.width, image.height, 0)
      se_x_off = structuring_element.width/2
      se_y_off = structuring_element.height/2

      if reflect
        reflect_mult = -1
      else
        reflect_mult = 1
      end

      image.height.times do |y|
        image.width.times do |x|
          dil_val = -Float::INFINITY
          structuring_element.each_with_coord do |val, se_x, se_y|
            next if val == -Float::INFINITY
            img_x = reflect_mult*(se_x - se_x_off) + x
            img_y = reflect_mult*(se_y - se_y_off) + y
            next if img_x < 0 || img_x >= image.width || img_y < 0 || img_y >= image.height

            img_val_nf = image[img_y, img_x] + val
            dil_val = img_val_nf if img_val_nf > dil_val
          end

          dilated_image[y, x] = dil_val
        end
      end

      return dilated_image
    end


    ##
    #Nearest neighbor interpolation
    def nearest_neighbor(scale_x, scale_y)
      if self.channels == 1
        interpolated_image = nearest_neighbor_gray(self, scale_x, scale_y)
      else
        interpolated_channels = self.each_channel.collect do |channel_img|
          nearest_neighbor_gray(channel_img, scale_x, scale_y)
        end
        interpolated_image = Imgrb::Image.new(*interpolated_channels)
      end

      return interpolated_image
    end

    ##
    #Nearest neighbor interpolation (single channel)
    def nearest_neighbor_gray(image, scale_x, scale_y)
      interpolated_img = Imgrb::Image.new((image.width*scale_x).round,
                                          (image.height*scale_y).round,
                                          [0]*image.channels)

      interpolated_img.height.times do |y_|
        y = y_+0.5 #Center of pixel is at idx+0.5
        y_orig_n = ((y/scale_y.to_f)-0.5).round #To find index remove 0.5 from position (see above)
        interpolated_img.width.times do |x_|
          x = x_+0.5
          x_orig_n = ((x/scale_x.to_f)-0.5).round
          interpolated_img[y_,x_] = image[y_orig_n,x_orig_n]
        end
      end

      return interpolated_img

    end

    ##
    #Bilinear interpolation
    def bilinear(scale_x, scale_y)
      if self.channels == 1
        interpolated_image = bilinear_gray(self, scale_x, scale_y)
      else
        interpolated_channels = self.each_channel.collect do |channel_img|
          bilinear_gray(channel_img, scale_x, scale_y)
        end

        interpolated_image = Imgrb::Image.new(*interpolated_channels)
      end

      return interpolated_image
    end

    ##
    #Linear interpolation.
    def linear_int(x0,y0,x1,y1,x)
      w = (x - x0)/(x1-x0)
      return y0*(1 - w) + y1*w
    end

    ##
    #Special case for x1 - x0 = 1
    def linear_int_special(y0, y1, x)
      w = x - x.to_i
      return y0*(1 - w) + y1*w
    end

    ##
    #Bilinear interpolation (single channel)
    #TODO: Clean up and optimize
    def bilinear_gray(image, scale_x, scale_y)
      interpolated_img = Imgrb::Image.new((image.width*scale_x).round,
                                          (image.height*scale_y).round,
                                          [0]*image.channels)

      (interpolated_img.height).times do |y_|
        y = y_+0.5 #Center of pixel is at idx+0.5
        y_orig = (y/scale_y.to_f - 0.5) #To find index remove 0.5 from position (see above)
        y_less = y_orig.floor
        y_more = y_orig.ceil
        y_more = y_less if y_more > image.height-1
        y_less = y_more if y_less < 0
        row_less = image.bitmap.rows[y_less]
        row_more = image.bitmap.rows[y_more]

        (interpolated_img.width).times do |x_|
          x = x_+0.5
          x_orig = (x/scale_x.to_f - 0.5)
          x_less = x_orig.floor
          x_more = x_orig.ceil
          x_more = x_less if x_more > image.width-1
          x_less = x_more if x_less < 0

          if x_less != x_more
            y_less_int = linear_int_special(row_less[x_less], row_less[x_more], x_orig)
            y_more_int = linear_int_special(row_more[x_less], row_more[x_more], x_orig)
          else
            y_less_int = row_less[x_less]
            y_more_int = row_more[x_less]
          end

          if y_less != y_more
            int_val = linear_int_special(y_less_int, y_more_int, y_orig)
          else
            int_val = y_less_int
          end

          interpolated_img[y_,x_] = int_val
        end
      end

      return interpolated_img
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



  end
end
