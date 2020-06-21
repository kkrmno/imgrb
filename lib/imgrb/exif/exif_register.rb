module Imgrb
  #Module containing classes and methods dealing with Exif data (for png).
  #See also  the ancillary chunk Chunks::ChunkeXIf
  module Exif

    @registered_exif_fields = Hash.new

    ##
    #Register an Exif field so that fields of that type in pngs containing an
    #eXIf chunk can be understood
    #Example:
    # register_exif_field([ifd0, ifd1, ifd_gps], tag_number, field_class_name)
    # register_exif_field(ifd0, tag_number, field_class_name)
    def self.register_exif_field(klass)

      ifds = Array(klass.possible_IFDs)
      tag = klass.tag

      name_to_check = klass.field_name
      if ["IFD0", "IFD1"].include? name_to_check
          warn "Using reserved name #{name_to_check} for Exif field object."
      end

      ifds = Array(ifds)
      ifds.each do
        |ifd|
        @registered_exif_fields[ifd] ||= Hash.new
        if @registered_exif_fields[ifd].include? tag
          warn "Overwriting previously registered Exif field, tag: #{tag}."
        end
        @registered_exif_fields[ifd][tag] = klass
      end
    end

    def self.register_exif_fields(*klasses)
      klasses.each{|klass| register_exif_field(klass)}
    end

    def self.get_exif_field(ifd_name, tag_id)
      registered_under_ifd = @registered_exif_fields.fetch(ifd_name, {})
      registered_under_ifd.fetch(tag_id, GenericField)
    end

    ##
    #Returns an array of IFDs to which tag IDs are registered
    def self.registered_IFDs
      @registered_exif_fields.keys
    end

    ##
    #Returns an array of tag IDs registered to the given IFDs
    def self.registered_tag_ids(*ifds)
      ifds = ifds.empty? ? self.registered_IFDs : ifds
      registered_ids = Set.new
      ifds.each do |ifd|
        @registered_exif_fields[ifd].keys.each{|key| registered_ids << key}
      end
      registered_ids.to_a
    end

    def self.registered_field_names(*ifds)
      ifds = ifds.empty? ? self.registered_IFDs : ifds
      names = Set.new
      ifds.each do |ifd|
        @registered_exif_fields[ifd].values.each{|field| names << field.field_name}
      end
      names.to_a
    end


    def self.create_field(field_data, pack_str, data, ifd_name)
      tag, type, type_pack_str, byte_len, count, value_or_offset = parse_field(field_data, pack_str)
      num_bytes = count * byte_len
      if num_bytes <= 4
        if pack_str == "n"
          value = value_or_offset[0...num_bytes]
        elsif pack_str == "v"
          # value = value_or_offset.reverse[0...num_bytes].reverse
          #TODO: Check if this should be reversed when little-endian! (see above)
          value = value_or_offset[0...num_bytes]
        else
          warn "Unexpected byte order in eXIf chunk!"
        end
      else
        offset = value_or_offset.unpack(pack_str.upcase)[0]
        value = data[offset...offset+num_bytes]
      end

      case type
      when :ascii
        if value.ascii_only?
          value = value.force_encoding("US-ASCII")
        else
          warn "Exif chunk contains non ASCII data incorrectly specified as ASCII"
        end
      when :rational, :srational
        #If little endian, flip numerator and denominator, so that numerator is
        #always first, regardless of endianness
        if pack_str == "v"
          denominator = value[0..3]
          numerator = value[4..7]
          value = numerator + denominator
        end
      end

      get_exif_field(ifd_name, tag).new(tag, value, type, type_pack_str)
    end



    private

    def self.parse_field(field_data, pack_str)
      tag = field_data[0..1].unpack(pack_str)[0]
      type_num = field_data[2..3].unpack(pack_str)[0]
      case type_num
      when 1
        type = :byte #8-bit unsigned
        type_pack_str = 'C'
        byte_len = 1
      when 2
        type = :ascii
        type_pack_str = 'C'
        byte_len = 1
      when 3
        type = :short #16-bit unsigned
        type_pack_str = pack_str
        byte_len = 2
      when 4
        type = :long #32-bit unsigned
        type_pack_str = pack_str.upcase
        byte_len = 4
      when 5
        type = :rational #Two 32-bit unsigned (numerator and denominator)
        type_pack_str = pack_str.upcase + pack_str.upcase
        byte_len = 8
      when 6
        type = :sbyte #Signed byte (type 6) unused in exif
        type_pack_str = 'c'
        byte_len = 1
      when 7
        type = :undefined #8-bit byte whose content depends on definition of field
        type_pack_str = 'C'
        byte_len = 1
      when 8
        type = :sshort #Signed short (type 8) unused in exif
        type_pack_str = 's' + pack_str == 'v' ? '<' : '>'
        byte_len = 2
      when 9
        type = :slong #32-bit signed (two's complement)
        type_pack_str = 'l' + pack_str == 'v' ? '<' : '>'
        byte_len = 4
      when 10
        type = :srational #signed rational (two's complement)
        type_pack_str = 'l' + pack_str == 'v' ? '<' : '>'
        type_pack_str += type_pack_str
        byte_len = 8
      when 11
        type = :float #Single-precision, 32-bit float (IEEE) unused in exif
        type_pack_str = pack_str == 'v' ? 'e' : 'g'
        byte_len = 4
      when 12
        type = :double #Double-precision, 64-bit float (IEEE) unused in exif
        type_pack_str = pack_str == 'v' ? 'E' : 'G'
        byte_len = 8
      else
        type = :unknown
        type_pack_str = 'C'
        byte_len = 1
      end
      count = field_data[4..7].unpack(pack_str.upcase)[0]
      value_or_offset = field_data[8..11]

      return [tag, type, type_pack_str, byte_len, count, value_or_offset]
    end

  end
end
