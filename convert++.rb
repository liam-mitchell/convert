require 'tk'

$current_warnings = []
$warnings = {}

def warn(msg)
  $current_warnings << msg
end

def parse_tiles(tiles)
  tilemap = {
    '0' => 0x00,
    '1' => 0x01,
    '2' => 0x09,
    '3' => 0x08,
    '4' => 0x07,
    '5' => 0x06,
    'F' => 0x1D,
    'G' => 0x1C,
    'H' => 0x1B,
    'I' => 0x1A,
    '>' => 0x15,
    '?' => 0x14,
    '@' => 0x13,
    'A' => 0x12,
    '6' => 0x11,
    '7' => 0x10,
    '8' => 0x0F,
    '9' => 0x0E,
    'O' => 0x03,
    'N' => 0x04,
    'Q' => 0x05,
    'P' => 0x02,
    'J' => 0x21,
    'K' => 0x20,
    'L' => 0x1F,
    'M' => 0x1E,
    'B' => 0x19,
    'C' => 0x18,
    'D' => 0x17,
    'E' => 0x16,
    ':' => 0x0D,
    ';' => 0x0C,
    '<' => 0x0B,
    '-' => 0x0A
  }

  rows = tiles.chars.map do |b|
    # todo warn on unrecognized tile
    if tilemap[b].nil?
      warn("unrecognized tile #{b}")
      next 0x00
    end

    tilemap[b]
  end.each_slice(23).to_a

  rows = Array.new(6, Array.new(23, 0x01)) + rows + Array.new(5, Array.new(23, 0x01))
  rows[0].zip(*rows.drop(1))
end

def coord(val)
  warn("z-snapped coordinate #{val} rounded") if val.to_i % 6 != 0
  val.to_i / 6
end

def orientation(val)
  val.to_i * 2
end

def mode(val)
  val = val.to_i
  if val < 0 || val > 3
    warn("invalid drone path #{val} defaulted to 0")
    return 0
  end

  val
end

def launchpad_orientation(x, y)
  return 0 if x == '1' && y == '0'
  return 4 if x == '-1' && y == '0'
  return 2 if x == '0' && y == '1'
  return 6 if x == '0' && y == '-1'
  return 7 if x =~ /0\.707/ && y =~ /-0\.707/
  return 5 if x =~ /-0\.707/ && y =~ /-0\.707/
  return 3 if x =~ /-0\.707/ && y =~ /0\.707/
  return 1 if x =~ /0\.707/ && y =~ /0\.707/

  warn("invalid launchpad power #{x}, #{y} defaulted to orientation 0")
  0
end

def parse_params(id, values)
  objectmap = {
    '0' => [0x02, :coord, :coord], # gold
    '1' => [0x11, :coord, :coord], # bounceblock
    '2' => [0x0A, :coord, :coord, :xpower, :ypower], # launchpad
    '3' => [0x13, :coord, :coord], # gauss
    '4' => [0x10, :coord, :coord, :unknown], # floorguard
    '5' => [0x00, :coord, :coord], # ninja
    '6' => [0xFF, :coord, :coord, :path, :seeker, :type, :orientation], # drone
    '7' => [0x0B, :coord, :coord, :orientation], # oneway
    '8' => [0x14, :coord, :coord, :orientation], # thwump
    '9' => [0xFF, :coord, :coord, :orientation, :type0, :doorx0, :doory0, :type1, :doorx1, :doory1], # door
    '10' => [0x12, :coord, :coord], # rocket
    '11' => [0x03, :coord, :coord, :keyx, :keyy], # exit
    '12' => [0x01, :coord, :coord] # mine
  }

  params = objectmap[id]
  obj = [params[0], coord(values[0].to_i + 6 * 24), coord(values[1])]
  key = nil

  # byebug

  case id
  when '2'
    obj << launchpad_orientation(values[2], values[3])
  when '6'
    case values[4]
    when '0'
      obj[0] = values[3] == '1' ? 0x0F : 0x0E # chaser/zap based on :seeker param
    when '1'
      obj[0] = 0x0D # laser
    when '2'
      obj[0] = 0x0C # chaingun
    end

    obj << orientation(values[5])
    obj << mode(values[2])
  when '7','8'
    obj << orientation(values[2])
    if obj[3] == 0
      obj[1] += 2
    elsif obj[3] == 2
      obj[2] += 2
    elsif obj[3] == 4
      obj[1] -= 2
    elsif obj[3] == 6
      obj[2] -= 2
    end
  when '9'
    obj << orientation(values[2])

    # byebug
    if values[6] == '1'
      obj[0] = 0x06
      key = [0x07, obj[1], obj[2]]
    elsif values[3] == '1'
      obj[0] = 0x08
      key = [0x09, obj[1], obj[2]]
    else
      obj[0] = 0x05
    end

    obj[1] = (values[4].to_i + 7) * 4 + values[7].to_i * 4
    obj[2] = values[5].to_i * 4 + values[8].to_i * 4

    if obj[3] == 2
      obj[1] -= 2
      obj[2] += 4
    else
      obj[2] += 2
    end
  when '11'
    key = [0x04, coord(values[2].to_i + 6 * 24), coord(values[3])]
  end

  [obj, key].compact
end

def parse_object(obj)
  id, params = obj.split('^')
  # byebug
  parse_params(id, params.split(','))
end

def parse_objects(objects)
  ret = {}
  (0..0x1C).each { |i| ret[i] = [] }
  # byebug
  # ret = Array.new(0x1C, [])

  objects.split('!')
    .map { |o| parse_object(o) }
    .each { |a| a.each { |o| ret[o[0]] << o } }

  ret
end

def parse_level(name, author, type, data)
  tiles, objects = data.split('|')
  tiles = parse_tiles(tiles)

  # $warnings.each { |w| puts "[warn] in tiles of #{name}: #{w}" }
  # $warnings = []

  # $warnings[name] = {}
  # $warnings[name][:tiles] = $current_warnings
  # $current_warnings

  objects = parse_objects(objects)
  # $warnings.each { |w| puts "[warn] in objects of #{name}: #{w}" }
  # $warnings = []

  $warnings[name] = $current_warnings
  $current_warnings = []

  {
    name: name,
    author: author,
    type: type,
    data: {tiles: tiles, objects: objects}
  }
end

def parse(file)
  File.read(file)
    .split('$')
    .drop(1)
    .map { |l| l.split('#') }
    .map { |a| parse_level(a[0], a[1], a[2], a[3]) }
end

def write_level(level, dir)
  data = [
    0x06, 0x00, 0x00, 0x00, # format version?
    0x00, 0x00, 0x00, 0x00, # fill size in once finished here
    0xFF, 0xFF, 0xFF, 0xFF, # unknown
    0x00, 0x00, 0x00, 0x00, # game mode - 0x00 == solo
    0x25, 0x00, 0x00, 0x00, # unknown
  ]

  name = "#{level[:name]} (#{level[:author]})".gsub(/\\|\/|\?/, '-').gsub(/"/, '\'')
  if name.length > 128
    name = name[0..127]
  end

  data += Array.new(4, 0xFF) # unknown
  data += Array.new(14, 0x00) # unknown
  data += name.unpack('c*') # level name
  data += Array.new(146 - name.length, 0x00) # level name - padded to 128 bytes, plus 18 bytes of null pad?
  data += level[:data][:tiles].flatten # tile data

  # byebug
  objs = level[:data][:objects].sort_by { |a| a[0] }
  objs.each do |a|
    id = a[0]
    objects = a[1]

    if id != 0x07 && id != 0x09
      data << (objects.length & 0xFF) # object counts
      data << ((objects.length >> 8) & 0xFF)
    else
      data << 0x00
      data << 0x00
    end
  end

  data += Array.new(22, 0x00)

  objs[0x06][1] = objs[0x06][1].zip(objs[0x07][1]).flatten(1)
  objs[0x08][1] = objs[0x08][1].zip(objs[0x09][1]).flatten(1)

  objs.each do |a|
    next if a[0] == 0x07 || a[0] == 0x09
    a[1].each { |o| data += o + Array.new(5 - o.length, 0x00) } # objects
  end

  data[4] = data.length & 0xFF
  data[5] = (data.length >> 8) & 0xFF
  data[6] = (data.length >> 16) & 0xFF
  data[7] = (data.length >> 24) & 0xFF

  # puts data
  data.each { |d| puts "invalid element #{d} in #{name}" if d.is_a?(String) }

  data = data.pack('C*')

  File.open(File.join(dir, name), 'wb') { |f| f.write(data) }
end

root = TkRoot.new
root.title = 'convert++'

# input = TkEntry.new(root) do
#   pack { padx 15 ; pady 15 ; side 'left' }
# end

# input = TkLabel.new(root)
# input.configure('text', 'Select input userlevels.txt file')

selectinput = TkButton.new(root) do
  text 'Select input userlevels.txt file'
  command proc { selectinput.text = Tk.getOpenFile }
  pack { padx 15 ; pady 15 ; side 'left' }
end

selectoutput = TkButton.new(root) do
  text 'Select output N++ levels directory'
  command proc { selectoutput.text = Tk.chooseDirectory }
  pack { padx 15 ; pady 15 ; side 'left' }
end

warnings = TkText.new(root) do
  pack { padx 15; pady 15; side 'left' }
end

convert = TkButton.new(root) do
  text 'Convert'

  command proc {
    i = selectinput.text
    o = selectoutput.text
    if i == '...' || o == '...' || !File.exist?(i) || !File.exist?(o)
      # warnings.text =
      warnings.insert 'end', 'You must select input and output files that exist!'
      return
    end

    parse(i).each { |l| write_level(l, o) }

    warnings.insert 'end', $warnings.map { |name, ws| ws.map { |w| "[warn] #{name}: #{w}" }.join("\n") }.join("\n")
  }

  pack { padx 15; pady 15; side 'left' }
end
# output = TkLabel.new(root) do
#   text 'Select output N++ levels directory'
# end

# selectoutput = TkButton.new(root) do
#   text '...'
# end

Tk.mainloop
