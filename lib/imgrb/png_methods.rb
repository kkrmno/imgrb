module Imgrb

  #General methods used when reading/writing png files.
  #[MOST OF THESE SHOULD PROBABLY BE PRIVATE!]
  module PngMethods  #:nodoc?:

    def self.known_ancillary_chunk?(chunk)
      chunk_type_ancillary?(chunk.type) && !Imgrb::Chunks.get_chunk_class(chunk.type).nil?
    end


    #Returns the length of the columns of an interlaced image
    #in the pass specified.

    #7 passes:
    #
    # 1 6 4 6 2 6 4 6
    # 7 7 7 7 7 7 7 7
    # 5 6 5 6 5 6 5 6
    # 7 7 7 7 7 7 7 7
    # 3 6 4 6 3 6 4 6
    # 7 7 7 7 7 7 7 7
    # 5 6 5 6 5 6 5 6
    # 7 7 7 7 7 7 7 7
    def self.find_interlaced_col_size(header, pass)
      h = header.height
      hmod = h % 8
      hdiv = h / 8
      hplus = 0

      case pass
      when 1
        hplus = 1 if hmod > 0
        hdiv + hplus
      when 2
        hplus = 1 if hmod > 0
        hdiv + hplus
      when 3
        hplus = 1 if hmod >= 5
        hdiv + hplus
      when 4
        if hmod >= 5
          hplus = 2
        elsif hmod > 0
          hplus = 1
        end
        2 * hdiv + hplus
      when 5
        if hmod >= 7
          hplus = 2
        elsif hmod >= 3
          hplus = 1
        end
        2 * hdiv + hplus
      when 6
        if hmod >= 7
          hplus = 4
        elsif hmod >= 5
          hplus = 3
        elsif hmod >= 3
          hplus = 2
        elsif hmod > 0
          hplus = 1
        end
        4 * hdiv + hplus
      when 7
        4 * hdiv + hmod / 2
      else
        return ArgumentError, "Pass must be between 1 and 7"
      end
    end

    ##
    #Returns the length of the rows of an interlaced image
    #in the pass specified.
    def self.find_interlaced_row_size(header, pass)
      w = header.width
      #w = header.bytes_per_row
      # wmod = w % 8  #1, 2, 4, and 16-bit?
      wdiv = w / 8
      wplus = 0
      per_row = [1,1,2,2,4,4,8]
      c = header.channels
      if pass ==  7
        size = c * w
      else
        wplus = find_extra_interlaced_row_size(header, pass)
        size = c * (per_row[pass-1] * wdiv + wplus)
      end

      size *= 2 if header.bit_depth == 16
      size = (size/(8.0/header.bit_depth)).ceil if header.bit_depth < 8

      #If the row is not empty (i.e. length 0), then account for the filter,
      #which adds one to the length
      size += 1 if size > 0
      return size
    end

    ##
    #Returns the length of the rows (in bits) of an interlaced image
    #in the pass specified.
    def self.find_interlaced_row_size_in_bits(header, pass)
      w = header.width
      # wmod = w % 8  #1, 2, 4, and 16-bit?
      wdiv = w / 8
      wplus = 0
      per_row = [1,1,2,2,4,4,8]
      c = header.channels
      if pass ==  7
        size = c * w
      else
        wplus = find_extra_interlaced_row_size(header, pass)
        size = c * (per_row[pass-1] * wdiv + wplus)
      end

      #If the row is not empty (i.e. length 0), then account for the filter,
      #which adds one to the length
      #size += 1 if size > 0
      return size
    end

    #Private
    #Help function for find_interlaced_row_size.
    #Calculates the "extra" pixels in the row of a interlaced
    #image for the specified pass.
    #I.e. the pixels that the last rectangle (horizontally)
    #possibly contributes to the pass, if it is wide enough
    #(the last rectangle does not have to be 8x8).
    def self.find_extra_interlaced_row_size(header, pass)
      w = header.width
      #w = header.bytes_per_row
      wmod = w % 8
      wplus = 0

      case pass
      when 1
        wplus = 1 if wmod > 0
      when 2
        wplus = 1 if wmod >= 5
      when 3
        if wmod >= 5
          wplus = 2
        elsif wmod > 0
          wplus = 1
        end
      when 4
        if wmod >= 7
          wplus = 2
        elsif wmod >= 3
          wplus = 1
        end
      when 5
        if wmod >= 7
          wplus = 4
        elsif wmod >= 5
          wplus = 3
        elsif wmod >= 3
          wplus = 2
        elsif wmod > 0
          wplus = 1
        end
      when 6
        if wmod >= 6
          wplus = 3
        elsif wmod >= 4
          wplus = 2
        elsif wmod >= 2
          wplus = 1
        end
      when 7
        wplus = wmod
      else
        return ArgumentError, "Pass must be between 1 and 7"
      end
      wplus
    end




    ##
    #Pass size for interlaced
    #
    #Make private?
    def self.find_pass_size(header, pass)
      find_interlaced_col_size(header, pass) *
      (find_interlaced_row_size(header, pass))
    end




    ##
    #Deinterlace interlaced image.
    def self.deinterlace(header, i_image)
      pass_images = []
      pass_filters = []
      passed = 0

      7.times do
        |pass|
        pass_filters << []
        pass_images << []
        # puts "Pass: #{pass+1}"
        col_size = find_interlaced_col_size(header, pass+1)
        # puts "#{col_size} columns in this pass."
        col_size.times do
          |col|
          # puts "Column #{col+1} in pass #{pass+1}"
          row_size = find_interlaced_row_size(header, pass+1)
          unless row_size == 0
            # puts "Row size in bytes: #{row_size}"
            # puts "Row size in bits: #{find_interlaced_row_size_in_bits(header, pass+1)}"
            row = i_image[passed...(passed+row_size)]
            if row.nil?
              raise Exceptions::ImageError, "Error in pass #{pass} while reading interlaced image."
            end
            pass_filters[pass] << row[0]
            if header.bit_depth < 8
              bit_row_size = find_interlaced_row_size_in_bits(header, pass+1)
              row = row[1..-1].collect!{|b| split_by_bits(b, header.bit_depth)}.flatten
              pass_images[pass] << row[0...bit_row_size]
            else
              pass_images[pass] << row[1..-1]
            end
            passed += row_size
          end
        end
      end

      [pass_filters, pass_images]
    end

    ##
    #This method takes the 7 passes from an interlaced png image (Adam7)
    #and returns the pixel array of the complete image.
    #
    #At this point each element in a pass should represent the value
    #of the corresponding pixels channel. I.e. 16-bit values need to
    #have been merged by this point, and <8-bit values must have been
    #split.
    #
    #7 passes:
    #
    # 1 6 4 6 2 6 4 6
    # 7 7 7 7 7 7 7 7
    # 5 6 5 6 5 6 5 6
    # 7 7 7 7 7 7 7 7
    # 3 6 4 6 3 6 4 6
    # 7 7 7 7 7 7 7 7
    # 5 6 5 6 5 6 5 6
    # 7 7 7 7 7 7 7 7
    #
    #Make private?
    def self.combine_passes(header, passes)
      start_row = [0, 0, 4, 0, 2, 0, 1]
      start_col = [0, 4, 0, 2, 0, 1, 0]
      row_inc   = [8, 8, 8, 4, 4, 2, 2]
      col_inc   = [8, 8, 4, 4, 2, 2, 1]

      w = header.width*header.channels
      h = header.height
      c = header.channels

      combined_image = Array.new(h){ Array.new(w) }

      passes.each_with_index do
        |img, pass|
        if img.size > 0
          row = start_row[pass]
          img.each_with_index do
            |img_row|
            col = start_col[pass]*c
            img_row.each_slice(c) do
              |pixel|
              combined_image[row][col...(col+c)] = pixel
              col += col_inc[pass]*c
            end
            row += row_inc[pass]
          end
        end
      end
      combined_image
    end




    ##
    #Decompresses an n-bit png image stream. Returns the filters as
    #an array and the image data as a 2D array.
    #CAREFUL: If n < 8 and the image is not interlaced, the image data is
    #returned already defiltered, else the image data is still filtered.
    def self.inflate_n_bit(header, png_image_stream, n)
      if n >= 8
        filters = []
        row_length = header.width*header.channels
        row_length *= 2 if n == 16 #2 bytes per channel for 16 bit images.
        image_data = inflate(png_image_stream).unpack("C*")

        if header.interlaced?
          return deinterlace(header, image_data)
        else
          #OPTIMIZE THIS!
          image_data = image_data.each_slice(row_length+1).collect do
            |s|
            filters << s.shift(1)[0]
            s
          end
          return [filters, image_data]
        end

      else

        image_data = []
        inflated_bytes = inflate(png_image_stream).unpack("C*")
        if header.interlaced?
          return deinterlace(header, inflated_bytes)
        else
          filters, img_data = get_filters(header, inflated_bytes)
          img_data = defilter(header, img_data, filters, false)
          img_data.each do
            |r|
            row = []
            r.each do
              |b|
              to_add = split_by_bits(b, n)
              to_add.each do
                |a|
                row << a
                break if row.size == header.width*header.channels
              end
            end
            image_data << row[0..header.width*header.channels-1]
          end
          #img_data = nil
          return [filters, image_data]
        end

      end

    end

    ##
    #Normalizes bytes in image data so that the maximal value
    #of any channel is 255. Useful when loading 16-bit images.
    def self.normalize_image_data(image_data)
      maximum = image_data.flatten.max
      divisor = maximum / 255.0
      image_data.collect! do
        |row|
        row.collect do
          |c|
          (c/divisor).round
        end
      end
    end

    ##
    #Merges pairs of bytes in each row of the image data.
    #Used when loading 16-bit images, since each channel
    #consists of two bytes in such cases.
    def self.merge_bytes(image_data)
      image_data.collect! do
        |row|
        row.each_slice(2).collect {|p| (p[0]*256 + p[1])}
      end
    end

    ##
    #Returns filters and filtered pixel values
    def self.get_filters(header, img)
      w = ((header.width/(8.0/header.bit_depth)).ceil*header.channels)+1

      starts = (0..(header.height-1)).collect{|x| x*w}
      image = []
      starts.each do
        |start|
        image << img[(start+1)..(start+w-1)]
      end

      filters = img.values_at(*starts)

      [filters, image]
    end

    ##
    #Takes the filtered inflated bytes and defilters them
    #Modifies image!
    #
    #Make private?
    #Note that filters are applied to _bytes_ not to pixels!
    #Unsigned arithmetic mod 256
    def self.defilter(header, image, filters, show_filters)
      bpp = header.channels  #Bytes per pixel
      bpp = bpp*2 if header.bit_depth == 16
      filters.each_with_index do
        |filter, i|
        row = image[i]
        if filter == 0                  #Do nothing if filter 0
          # if show_filters
          #   row.each_with_index do
          #     |b, index|
          #     image[i][index] = 255
          #   end
          # end
        elsif filter == 1               #Defilter subtract
          row.each_with_index do
            |b, index|
            if index >= bpp
              l = row[index-bpp]
            else
              l = 0
            end
            row[index] = (b + l)%256
            # image[i][index] = (b + l)%256
            # image[i][index] = 200 if show_filters
          end
        elsif filter == 2       #Defilter up
          row.each_with_index do
            |b, index|
            if i > 0
              u = image[i-1][index]
            else
              u = 0
            end
            row[index] = (b + u)%256
            image[i][index] = 100 if show_filters
          end
        elsif filter == 3       #Defilter average
          row.each_with_index do
            |b, index|
            if index >= bpp
              l = row[index-bpp]
            else
              l = 0
            end
            if i > 0
              u = image[i-1][index]
            else
              u = 0
            end
            row[index] = (b + ((l+u)/2).floor)%256
            image[i][index] = 60 if show_filters
          end
        elsif filter == 4       #Defilter Paeth
          row.each_with_index do
            |b, index|
            ul = image[i-1][index-bpp] if i > 0 && index >= bpp
            if index >= bpp
              l = row[index-bpp]
            else
              l = 0
              ul = 0
            end
            if i>0
              u = image[i-1][index]
            else
              u = 0
              ul = 0
            end
            row[index] = (b + paeth_predictor(l, u, ul))%256
            image[i][index] = 0 if show_filters
          end
        else
          raise ArgumentError, "Unknown filter type: #{filter}"
        end
      end
      return image
    end

    ##
    #Replaces indexes with palette values in bitmap
    #Note that the palette pixel values are RGB 8-bit.
    def self.depalette(bitmap)
      image = bitmap.rows
      palette = bitmap.palette
      transparency_palette = bitmap.transparency_palette
      return image if palette == []
      depaletted = []
      row = []
      image.each do
        |r|
        r.each do
          |i|
          if palette == []
            row << i
          else
            row << palette[i*3]
            row << palette[i*3+1]
            row << palette[i*3+2]
          end
          if transparency_palette != []
            alpha = transparency_palette[i]
            alpha = 255 if alpha.nil?
            row << alpha
          end
        end
        depaletted << row
        row = []
      end
      return depaletted
    end

    ##
    #Apply transparence palette
    def self.use_transparency_color(header, bitmap)
      image = bitmap.rows
      if header.has_alpha?
        #No tRNS chunk should be present, since the image has an alpha channel.
        warn "Transparency palette present in a png of color type: "\
             "#{header.color_type}. Ignoring it."
        return image
      end
      t_color = bitmap.transparency_palette
      t_image = []
      t_row = []
      pixel_size = header.channels
      image.each do
        |row|
        row.each_slice(pixel_size) do
          |pixel|
          pixel_size.times do
            |i|
            t_row << pixel[i]
          end
          if pixel == t_color
            t_row << 0
          else
            t_row << 255
          end
        end
        t_image << t_row
        t_row = []
      end
      return t_image
    end

    ##
    #Rescales to 8-bit values
    def self.read_grayscale(header, image)
      num_of_colors = 2**header.bit_depth
      num_of_colors = 256 if num_of_colors > 256
      graystep = 255/(num_of_colors-1)
      gray_scale_img = []
      row = []
      image.each do
        |r|
        r.each_with_index do
          |gray_or_alpha, i|
          gray_or_alpha = 256 if gray_or_alpha > 256
          if !header.has_alpha?
            #3.times {row << gray_or_alpha*graystep}
            row << gray_or_alpha*graystep
          else
            if i%2 == 0
              #3.times {row << gray_or_alpha*graystep}
              row << gray_or_alpha*graystep
            else
              row <<  gray_or_alpha #This adds alpha
            end
          end
        end
        gray_scale_img << row
        row = []
      end
      return gray_scale_img
    end


    def self.split_by_bits(byte, size)
      if size == 4
        return [(byte & 0b11110000) >> 4, byte & 0b00001111]
      elsif size == 2
        return [(byte & 0b11000000) >> 6, (byte & 0b00110000) >> 4,
                (byte & 0b00001100) >> 2,  byte & 0b00000011       ]
      elsif size == 1
        return [byte[7], byte[6], byte[5], byte[4],
                byte[3], byte[2], byte[1], byte[0]]
      else
        raise ArgumentError,
            "Size argument should be 1, 2, or 4. "\
            "Size argument given: #{size}."
      end
    end

    ##
    #Quick test to check if palettable image.
    #Takes Image instance and an optional parameter samples.
    #Returns false if the image is not palettable, true if
    #it _may_ be so.
    def self.palettable?(img, samples = 3000)
      n_pixels = img.width*img.height
      return true if n_pixels <= 256
      bytes_per_color = 3
      bytes_per_color = 4 if img.has_alpha?
      image_data = img.rows
      samples = n_pixels if samples > n_pixels
      test_colors = []
      samples.times do  #Sample pixels at random, see how many unique colors.
        x = rand(img.width)*bytes_per_color
        y = rand(img.height)
        test_colors << image_data[y][x..x+2]
      end
      if test_colors.uniq.size <= 256
        return true         #May be possible to use palette.
      else
        return false        #Definitiely not possible to use palette.
      end
    end

    ##
    #Try to convert an image to a paletted one. Returns palette and the
    #palette idxs
    def self.palette(img)
      has_alpha = img.has_alpha?
      palette_hash = Hash.new
      paletted_image = []
      bytes_per_color = 3
      bytes_per_color += 1 if has_alpha
      catch(:max_exceeded) do
        img.rows.each do
          |row|
          row.each_slice(bytes_per_color) do
            |pixel|
            throw :max_exceeded if palette_hash.size > 256

            pxl = pixel[0..2]
            unless palette_hash.has_key? pxl
              palette_hash[pxl] = palette_hash.size
            end
            paletted_image << palette_hash[pxl]
          end
        end
      end
      if palette_hash.size > 256
        palette_hash = Hash.new
        paletted_image = []
      end
      return [palette_hash.keys.flatten, paletted_image]
    end

    ##
    #Takes an Image instance and tries to save it as a paletted image.
    #returns true if success, false if failure
    def self.try_palette_save(img, file, compression_level, samples = 3000, skip_ancillary = false)
      #Do not palette grayscale images. At the moment it is too much of a hassle
      #to try to palette images with an alpha channel, so don't.

      #16-bit paletted not valid png-format
      return false if img.header.bit_depth == 16

      header = img.header.to_png_header

      return false if header.grayscale? || img.has_alpha?
      palette = []

      if palettable?(img, samples)
        palette, paletted_image = palette(img)
      end
      if palette.size > 0 && palette.size <= 256*3
        save_png_paletted(img, header, file, compression_level,
                          palette, paletted_image, skip_ancillary)
        return true
      else
        return false
      end
    end

    ##
    #Get all chunks from a png file and return them as an array of chunk instances.
    def self.read_png(image_bytes, skip_ancillary, skip_crc)
      chunk_dat = read_chunk(8, 0, image_bytes,
                             skip_ancillary, skip_crc, "NONE")
      chunks = []
      if chunk_dat[0].type != "IHDR"
        raise Exceptions::ImageError, "First chunk of the png is not IHDR!"
      end
      chunks << chunk_dat[0]
      read_at = chunk_dat[1]
      at_end = (chunk_dat[0].type == "IEND")
      last_chunk = chunk_dat[0].type
      while !at_end
        last_critical = last_chunk if !chunk_type_ancillary?(last_chunk)
        chunk_dat = read_chunk(read_at, chunks.length, image_bytes,
                               skip_ancillary, skip_crc, last_critical)
        last_chunk = chunk_dat[0].type
        read_at = chunk_dat[1]
        if chunk_dat[0].required_pos != :nowhere
          chunks << chunk_dat[0]
          at_end = (chunk_dat[0].type == "IEND")
        end
      end
      return chunks
    end

    ##
    #Extracts chunk data from the png file at a byte level.
    #Needs the chunk position "at" (i.e. at which byte
    #does it start?). There should be pos-1 chunks before this one in the file.
    #Returns an array containing
    #[chunk instance, position of last byte of chunk]
    #Where the chunk instances are chunk objects of registered types (or generic ones)
    def self.read_chunk(at, pos, image_bytes, skip_ancillary, skip_crc, last_critical)
      if (at+8) <= image_bytes.size
        #data_length = read_chunk_data_length(at, image_bytes)
        end_of_chunk = at + read_chunk_total_length(at, image_bytes)
        if (end_of_chunk) <= image_bytes.size

          chunk_ascii = read_chunk_name(at, image_bytes)
          crc = read_chunk_crc(at, image_bytes)
          chunk_data = read_chunk_data(at, image_bytes) #Raw data
          chunk_rel_pos = :unknown

          critical = !chunk_type_ancillary?(chunk_ascii)  #I.e. not ancillary

          if last_critical == "IHDR"
            chunk_rel_pos = :after_IHDR
          elsif last_critical == "PLTE"
            chunk_rel_pos = :after_PLTE
          elsif last_critical == "IDAT"
            chunk_rel_pos = :after_IDAT
          else
            #If an unknown critical chunk has been encountered
            #there are bigger problems.
            chunk_rel_pos = :unknown
          end

          if skip_ancillary && !critical
            return [Chunks::ChunkskIP.new("", chunk_rel_pos), end_of_chunk]
          end

          #Reserved for future extensions to png spec.
          #For now should always be uppercase.
          reserved = chunk_type_reserved?(chunk_ascii)
          #Safe to copy to a modified datastream.
          #Handled by create_chunk
          # safe = chunk_type_safe?(chunk_ascii)

          warn "Chunk: reserved bit set" if reserved


          chunk = create_chunk(chunk_ascii, chunk_data, chunk_rel_pos)
          if !skip_crc && chunk.crc != crc.pack("C*")
            if chunk.critical?
              raise Imgrb::Exceptions::CrcError, "Critical chunk "\
                                                 "'#{chunk.type}' failed crc "\
                                                 "check."
            else
              warn "Ancillary chunk '#{chunk.type}' failed crc check. "\
                   "It has been skipped."
              chunk = Chunks::ChunkskIP.new("", chunk_rel_pos)
            end
          end
          return [chunk, end_of_chunk]
        else
          raise Imgrb::Exceptions::ImageError, "Reached end of file while reading chunk."
        end
      else
        warn "Missing IEND chunk? File may be corrupt. Attempting to repair."
        chunk = Chunks::ChunkIEND.new("", chunk_rel_pos)
        return [chunk, -1]
      end
    end

    ##
    #Get length of chunk in bytes
    def self.read_chunk_data_length(at, img)
      Shared::interpret_bytes_4(img[at..(at+3)].unpack("C*"))
    end

    ##
    #Get chunk name
    def self.read_chunk_name(at, img)
      img[(at+4)..(at+7)]
    end

    ##
    #Get chunk crc
    def self.read_chunk_crc(at, img)
      data_length = read_chunk_data_length(at, img)
      img[(at + 8 + data_length)..(at + 8 + data_length + 3)].unpack("C*")
    end

    ##
    #Get data contained in chunk
    def self.read_chunk_data(at, img)
      data_length = read_chunk_data_length(at, img)
      img[(at + 8)..(at + 7 + data_length)]
    end

    ##
    #Get total chunk length in bytes (including non-data bytes)
    def self.read_chunk_total_length(at, img)
      8 + read_chunk_data_length(at, img) + 4
    end

    ##
    #Does the name indicate an ancillary chunk?
    def self.chunk_type_ancillary?(type)
      !(type[0].upcase == type[0])
    end

    ##
    #Does the name indicate a public chunk, i.e. one registered officially?
    def self.chunk_type_public?(type)
      (type[1].upcase == type[1])
    end

    ##
    #Does the name indicate a reserved chunk type?
    def self.chunk_type_reserved?(type)
      !(type[2].upcase == type[2])
    end

    ##
    #Does the name indicate the chunk is safe to copy?
    def self.chunk_type_safe?(type)
      !(type[3].upcase == type[3])
    end

    ##
    #Create a new chunk instance from the chunk register
    def self.create_chunk(type, chunk_data, pos)
      chunk_class = Imgrb::Chunks.get_chunk_class(type)
      if chunk_class.nil?
        create_unknown_chunk(type, chunk_data,  pos)
      else
        chunk_class.new(chunk_data, pos)
      end
    end

    ##
    #Create a generic unknown ancillary chunk
    def self.create_unknown_chunk(type, chunk_data, pos)
      if !chunk_type_ancillary?(type)
        raise Imgrb::Exceptions::ChunkError, "Trying to create an unknown "\
                                             "critical chunk: #{type}."
      else
        if chunk_type_safe?(type)
          return Chunks::ChunkSafe.new(type, chunk_data, pos)
        else
          return Chunks::ChunkUnsafe.new(type, chunk_data, pos)
        end
      end
    end

    ##
    #Try different filters and compress each row to try to find the best filtering
    #strategy. (Kind of expensive)
    def self.find_best_row_filter(row, image, bpp)
      best_row = filter_row(image, row, 0, bpp)
      best_filter = 0
      # z = Zlib::Deflate.new(Zlib::BEST_COMPRESSION, 15,
                           # Zlib::MAX_MEM_LEVEL, Zlib::DEFAULT_STRATEGY)
      #c = z.deflate(chunk, Zlib::FINISH)
      best = Zlib::Deflate.deflate(best_row.pack('C*')).size
      # best = z.deflate(best_row.pack('C*'), Zlib::FINISH).size
      4.times do
        |i|
        filter = i + 1
        filtered = filter_row(image, row, filter, bpp)
        filtered_comp_size = Zlib::Deflate.deflate(filtered.pack('C*')).size
        if filtered_comp_size < best
          best_row = filtered
          best_filter = filter
        end
      end
      [best_row, best_filter]
    end

    #Private
    #This method tries to find the optimal filters to use when compressing
    #a png image.
    #Compression level 0 ignores filtering (i.e. filter 0 for every row),
    #compression level 1 tries to choose the best filter for each row as
    #follows:
    #For each row, try every filter, compressing after every time.
    #Use the filter that yields the best compression for that row.
    #This means that the complete image is compressed 5 times during
    #this process.
    def self.filter_for_compression(image, compression_level, bpp)
      #Spend more effort trying to minimize file size. Slower.
      if compression_level == 1
        filtered_image = []
        filters = []
        image.each_index do
          |row|
          best_row, best_filter = find_best_row_filter(row, image, bpp)
          filtered_image << best_row
          filters << best_filter
        end
        return [filters, filtered_image]
      elsif compression_level == 0
        #No filtering
        return [[0]*image.size, image.collect {|row| row.clone}]
      else
        raise ArgumentError, "Unknown compression level: #{compression_level}."
      end
    end

    #Private
    def self.get_header_bytes(img, header, color_type = header.image_type, bit_depth = 8)
      header.print_header(color_type, bit_depth)
    end

    ##
    #Get PLTE chunk bytes
    def self.get_palette_bytes(palette)
      chunk = palette.pack('C*')
      crc = [Zlib.crc32("PLTE" << chunk, 0)].pack('N')
      return [palette.size].pack('N') << "PLTE" << chunk << crc
    end

    #Private
    def self.get_background_bytes(img, header)
      return "" if img.background_color == [] || img.background_color.nil?

      if header.grayscale?
        if img.background_color.size != 1
          warn "Background color has the wrong number of channels: "\
               "#{img.background_color.size} instead of 1. Dropping chunk."
               return ""
        else
          chunk = [0, img.background_color[0]]
          chunk_size = 2
        end

      else
        if img.background_color.size != 3
          warn "Background color has the wrong number of channels: "\
               "#{img.background_color.size} instead of 3. Dropping chunk."
          return ""
        else
          chunk = img.background_color
          chunk = [0,0,0].zip(chunk).flatten
          chunk_size = 6
        end
      end

      chunk = chunk.pack('C*')
      crc = [Zlib.crc32("bKGD" << chunk, 0)].pack('N')
      return [chunk_size].pack('N') << "bKGD" << chunk << crc
    end

    #Private
    def self.get_idat_bytes(filters, filtered_image, is_16_bit = false)
      chunk = ""
      #.pack('n*') for 16-bit images!
      if is_16_bit
        pack_str = "n*"
      else
        pack_str = "C*"
      end
      filters.each.with_index do
        |filter, i|
        chunk << filter.chr << filtered_image[i].pack(pack_str)
      end
      #TODO: Add option for BEST_SPEED?
      #Zlib:RLE available in standardlib Ruby >=2.0 but not clear when this is a
      #good option. Perhaps should try after refining choices of png filters.
      z = Zlib::Deflate.new(Zlib::BEST_COMPRESSION, Zlib::MAX_WBITS,
                             Zlib::MAX_MEM_LEVEL, Zlib::DEFAULT_STRATEGY)
      chunk = z.deflate(chunk, Zlib::FINISH)
      z.close

      crc = [Zlib.crc32("IDAT" << chunk, 0)].pack('N')

      return [chunk.size].pack('N') << "IDAT" << chunk << crc
    end

    #Private
    def self.ancillary_chunk_bytes(img)
      after_head_bytes = ""
      after_plte_bytes = ""
      after_idat_bytes = ""

      #Order is important here (breaks png spec).
      apng_special_byte_array =  Array.new(2*img.header.number_of_frames, "")

      img.ancillary_chunks.values.each do
        |chunk_arr| #Contains all ancillary chunks of the same type
        chunk_arr.each do
          |chunk|
          #TODO: Implement critical_changes_made?
          if img.header.to_png_header.critical_changes_made? && !chunk.safe?
            #If image data has been changed ancillary, unsafe chunks should be
            #updated to be made safe to copy over to the modified image
            #TODO: This should probably happen before saving (immediately when
            #updating an image or making a copy and changing that copy)
            safe_to_write = chunk.make_safe!
          else
            safe_to_write = true
          end
          if safe_to_write
            bytes = chunk.get_raw
            req_pos = chunk.required_pos


            if req_pos == :none
              #Put ancillary chunks with no requirements on position
              #after the last IDAT chunk.
              req_pos = :after_IDAT
            elsif req_pos == :unknown
              #Put ancillary chunks with unknown positional requirements
              #at the position they were found when they were read in.
              if known_ancillary_chunk?(chunk)
                warn "The required position of a known ancillary chunk "\
                     "#{chunk.type} is unknown. This should be fixed."
              end

              #If an unknown chunk is read from a png file, this should give
              #a compliant required position of the unknown chunk (possibly
              #stricter than necessary).
              req_pos = chunk.pos
            elsif req_pos == :apng_special
              req_pos = chunk.pos
            end

            if req_pos == :after_IHDR
              after_head_bytes << bytes
            elsif req_pos == :after_PLTE
              after_plte_bytes << bytes
            elsif req_pos == :after_IDAT
              #Special case for apng
              if chunk.type == "fcTL"
                apng_special_byte_array[chunk.sequence_number] = bytes
              elsif chunk.type == "fdAT"
                apng_special_byte_array[chunk.sequence_number] = bytes
              else
                after_idat_bytes << bytes
              end
            end
            #Skip any ancillary chunks that appear after
            #unknown critical chunks.
          end
        end
      end
      after_idat_bytes << apng_special_byte_array.join("")
      [after_head_bytes, after_plte_bytes, after_idat_bytes]
    end

    ##
    #Creates an array of pieces of a png file corresponding to img (as bytes)
    def self.generate_png(img, header, compression_level, skip_ancillary)

      color_type = header.image_type
      if color_type == Imgrb::PngConst::INDEXED
        raise Imgrb::Exceptions::HeaderError, "Image should have been "\
                                              "converted from an indexed "\
                                              "format to a truecolor image "\
                                              "(possibly with alpha) at "\
                                              "this point."
      end

      bpp = header.channels

      #TODO: Implement better compression for 16-bit images
      if header.bit_depth == 16
        compression_level = 0
        is_16_bit = true
        bit_depth_to_write = 16
      elsif [1, 2, 4, 8].include? header.bit_depth
        is_16_bit = false
        bit_depth_to_write = 8
      else
        raise Imgrb::Exceptions::HeaderError, "invalid png bit depth: #{header.bit_depth}"
      end

      #Calculate filters and filter the image.
      filters, filtered_image = filter_for_compression(img.rows,
                                                       compression_level, bpp)

      head_bytes = get_header_bytes(img, header, color_type, bit_depth_to_write)
      plte_bytes = ""
      bg_bytes   = get_background_bytes(img, header) #Might want to handle this
                                                     #as a regular ancillary
                                                     #chunk instead.
      idat_bytes =  get_idat_bytes(filters, filtered_image, is_16_bit)

      if skip_ancillary
        after_hd = after_plte = after_idat = ""
      else
        after_hd, after_plte, after_idat = ancillary_chunk_bytes(img)
      end

      png_start = PngConst::PNG_START.dup
      png_end = PngConst::PNG_END.dup
      return [png_start, head_bytes, after_hd, plte_bytes, bg_bytes,
              after_plte, idat_bytes, after_idat, png_end]
    end

    ##
    #Saves img as a png
    def self.save_png(img, header, file, compression_level, skip_ancillary)

      png_arr = generate_png(img, header, compression_level, skip_ancillary)

      file << png_arr[0] #Store PNG signature
      file << png_arr[1] #Store IHDR chunk
      file << png_arr[2] #Store ancillary chunks after IHDR
      file << png_arr[3] #Store PLTE chunk
      file << png_arr[4] #Store bKGD chunk (has to be after PLTE)
      file << png_arr[5] #Store ancillary chunks after PLTE
      file << png_arr[6] #Store image data in a single IDAT chunk
      file << png_arr[7] #Ancillary chunks after IDAT chunk
      file << png_arr[8] #Add IEND chunk with CRC
    end

    #Private
    def self.save_png_paletted(img, header, file, compression_level,
                               palette, paletted_image, skip_ancillary)
      png_image = PngConst::PNG_START #PNG signature

      if skip_ancillary
        after_hd = after_plte = after_idat = ""
      else
        after_hd, after_plte, after_idat = ancillary_chunk_bytes(img)
      end

      #Store IHDR chunk
      png_image += get_header_bytes(img, header, Imgrb::PngConst::INDEXED)

      png_image << after_hd

      #Store PLTE chunk.
      png_image << get_palette_bytes(palette)

      png_image << after_plte

      #Store  bKGD chunk
      png_image << get_background_bytes(img, header)

      #Calculate filters and filter the image.
      rows = paletted_image.each_slice(img.width).to_a
      filters, filtered_image = filter_for_compression(rows,
                                                       compression_level, 1)

      #Store image data in a single IDAT chunk
      png_image << get_idat_bytes(filters, filtered_image)

      png_image << after_idat

      #Store IEND chunk. Always the same.
      png_image << PngConst::PNG_END #Add IEND chunk with CRC

      file.print png_image
    end

    ##
    #Inflate the string
    def self.inflate(string)
      # string_io = StringIO.new(string)
      zstream = Zlib::Inflate.new(Zlib::MAX_WBITS)
      # buf = zstream.inflate(string_io.read)
      buf = zstream.inflate(string)
      zstream.finish #Problems?
      zstream.close
      buf
    end

    ##
    #Deflate the string
    def self.deflate(string)
      z = Zlib::Deflate.new(Zlib::BEST_COMPRESSION, Zlib::MAX_WBITS,
                             Zlib::MAX_MEM_LEVEL, Zlib::DEFAULT_STRATEGY)
      compressed = z.deflate(string, Zlib::FINISH)
      z.close
      compressed
    end

    def self.paeth_predictor(a, b, c)
      p = (a + b - c)
      pa = (p-a).abs
      pb = (p-b).abs
      pc = (p-c).abs
      if pa <= pb && pa <= pc
        return a
      elsif pb <= pc
        return b
      else
        return c
      end
    end

    def self.apply_subtract_filter(srow, row, bpp)
      srow.each_index do
        |index|
        b = srow[index]
        if index >= bpp
          l = srow[index-bpp]
        else
          l = 0
        end
        row[index] = (b - l)%256
      end
    end

    def self.apply_up_filter(r, srow, row, image)
      srow.each_index do
        |index|
        b = srow[index]
        if r > 0
          u = image[r-1][index]
        else
          u = 0
        end
        row[index] = (b - u)%256
      end
    end

    def self.apply_average_filter(r, srow, row, image, bpp)
      srow.each_index do
        |index|
        b = srow[index]
        if index >= bpp
          l = srow[index-bpp]
        else
          l = 0
        end
        if r > 0
          u = image[r-1][index]
        else
          u = 0
        end
        row[index] = (b - ((l+u)/2).floor)%256
      end
    end

    def self.apply_paeth_filter(r, srow, row, image, bpp)
      srow.each_index do
        |index|
        b = srow[index]
        ul = image[r-1][index-bpp]
        if index >= bpp
          l = srow[index-bpp]
        else
          l = 0
          ul = 0
        end
        if r>0
          u = image[r-1][index]
        else
          u = 0
          ul = 0
        end
        row[index] = (b - paeth_predictor(l, u, ul))%256
      end
    end



    #Filters row r of the image with filter and returns the resulting row.
    #A pixel in the image has bpp bytes per pixel.
    def self.filter_row(image, r, filter, bpp)
      row = image[r].clone
      srow = image[r]
      if filter == 1  #Subtract
        apply_subtract_filter(srow, row, bpp)
      elsif filter == 2   #Filter up
        apply_up_filter(r, srow, row, image)
      elsif filter == 3   #Filter average
        apply_average_filter(r, srow, row, image, bpp)
      elsif filter == 4   #Filter Paeth
        apply_paeth_filter(r, srow, row, image, bpp)
      end
      row
    end

    ##
    #Returns the number of channels for a given png color type
    def self.channels(color_type)
      if color_type    == Imgrb::PngConst::GRAYSCALE       #Grayscale
        return 1
      elsif color_type == Imgrb::PngConst::INDEXED         #Indexed-color
        return 1
      elsif color_type == Imgrb::PngConst::GRAYSCALE_ALPHA #Grayscale w/ alpha
        return 2
      elsif color_type == Imgrb::PngConst::TRUECOLOR       #Truecolor
        return 3
      elsif color_type == Imgrb::PngConst::TRUECOLOR_ALPHA #Truecolor w/ alpha
        return 4
      end
    end

    private_class_method :filter_for_compression, :find_best_row_filter,
    :get_header_bytes, :get_background_bytes,
    :get_idat_bytes, :save_png_paletted, :read_chunk,
    :apply_subtract_filter, :apply_up_filter, :apply_average_filter,
    :apply_paeth_filter, :ancillary_chunk_bytes
  end
end
