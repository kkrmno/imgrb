module Imgrb

  ##
  #Creates a 1D Gaussian filter with given +sigma+ (default: 1).
  #+cutoff+ specifies how much of the bell is kept at either side of the origin
  #(default: 3*sigma)
  def self.gaussian(sigma = 1, cutoff = (3 * sigma))
    #TODO: warn if sigma < 1?
    cutoff = cutoff.ceil
    #Cut off the Gaussian after a certain point.
    support = 2 * cutoff + 1
    gaussian_1d = Image.new(support, 1, 0)

    (-cutoff).upto(cutoff).with_index do |x, idx|
      val = 1.0/(Math.sqrt(2*Math::PI)*sigma)*Math.exp(-x**2/(2.0*sigma**2))
      gaussian_1d.set_pixel(idx, 0, val)
    end

    #Force values to sum up to 1
    gaussian_1d / gaussian_1d.inject(:+)
  end

  ##
  #Creates a 1D Gaussian derivative filter with given +sigma+ (default: 1).
  #+cutoff+ specifies the size of the support of the filter to either side of
  #the origin (default: (3.5*sigma))
  def self.gaussian_deriv(sigma = 1, cutoff = 3.5 * sigma)
    cutoff = cutoff.ceil
    gaussian_1d = self.gaussian(sigma, cutoff)
    xs = Imgrb.sequential(-cutoff, cutoff)

    -(gaussian_1d * xs) / sigma**2
  end

  ##
  #Returns an image containing only zeros.
  #* +zeros+(+n+) returns an n-by-n grayscale image of zeros
  #* +zeros+(+width+, +height+) returns a width-by-height grayscale image of zeros
  #* +zeros+(+width+, +height+, +channels+) returns a width-by-height image of zeros with the specified number of channels
  def self.zeros(*sizes)
    if sizes.length > 3
      raise ArgumentError, "Expected <= 3 size arguments (got: #{sizes.length})"
    elsif sizes.length == 3 && sizes[2] > 4
      raise ArgumentError, "The number of channels must be <= 4 (got: #{sizes[3]})"
    elsif sizes.length < 1
      raise ArgumentError, "Expected > 0 arguments (got: #{sizes.length})"
    end

    if sizes.length == 1
      width = sizes[0]
      height = width
      channels = 1
    elsif sizes.length == 2
      width = sizes[0]
      height = sizes[1]
      channels = 1
    elsif sizes.length == 3
      width = sizes[0]
      height = sizes[1]
      channels = sizes[2]
    end

    Imgrb::Image.new(width, height, [0]*channels)
  end


  ##
  #Returns an image containing only ones.
  #* +ones+(+n+) returns an n-by-n grayscale image of ones
  #* +ones+(+width+, +height+) returns a width-by-height grayscale image of ones
  #* +ones+(+width+, +height+, +channels+) returns a width-by-height image of ones with the specified number of channels
  def self.ones(*sizes)
    zeros(*sizes) + 1
  end

  ##
  #Returns a 1D image (a row of pixels) containing pixels with constantly increasing/decreasing values between a start and end value.
  #* +sequential+(+start+, +stop+) returns a row of values start..stop (grayscale)
  #* +sequential+(+start+, +stop+, +step+) returns a row of values between start and stop incrementing by step (grayscale). Note that the step may be negative.
  #* +sequential+(+start+, +stop+, +step+, +c+) returns a row of values between start and stop incrementing by step (c channels)
  def self.sequential(start, stop, step_len = 1, channels = 1)
    row_values = [start.step(stop, step_len).to_a]
    image_row = Imgrb::Image.new(row_values, PngConst::GRAYSCALE)

    if channels > 1
      image = Imgrb::Image.new(image_row.width, 1, [0]*channels)
      channels.times do |c|
        image.set_channel(c, image_row)
      end
      image_row = image
    end

    return image_row
  end

  ##
  #Returns a 2D image of a disk, where the background is filled with 0 and the disk is filled with 1
  #* +disk+(+r+) returns a disk of radius +r+
  #* +disk+(+r+, +c+) returns a disk of radius +r+ as an image with +c+ channels.
  def self.disk(radius, channels = 1)
    radius_integer = radius.ceil
    size = radius_integer * 2 + 1
    disk = Imgrb::Image.new(size, size, [0]*channels)
    origin = radius_integer

    size.times do |y|
      size.times do |x|
        xd = x - origin
        yd = y - origin
        dist = Math.sqrt(xd**2 + yd**2)

        disk.set_pixel(x,y,[1]*channels) if dist <= radius
      end
    end
    return disk
  end

end
