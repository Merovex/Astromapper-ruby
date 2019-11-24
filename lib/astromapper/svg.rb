module Astromapper
  class Svg
    def config
      Astromapper.config
    end
    def initialize(filename)
      @rows     = 40
      @columns  = 32
      @source_filename = filename
      sectorname = filename.gsub(File.extname(filename), '')
      @svg_filename    = sectorname + '.svg'
      @side    = 40
      @factor  = 1.732
      @height  = (@side * @factor * (@rows + 0.5)).ceil
      @width   = (@side * (@columns * 1.5 + 0.5)).ceil
      @mark    = 13
      @zones   = []
      @volumes = []
      # @routes  = {}
      @routes = []
      @slopes = {}
      @name = config['name']

      @hex = {
        :side_h => (@side * (@factor / 2)).tweak,
        :side_w => (@side / 2).tweak,
        :width  => @side
      }
    end
    def from_file
      File.open(@source_filename,'r').readlines.each { |line| @volumes << line if /^\d{4}/.match(line) }
    end
    def calc_route(x,m,y,n)
      route = nil
      x1 = (x + m)
      y1 = (y + n)
      return nil if y1 > 40
      return nil if x1 > 32
      # Calcuate Route Distance
      d = Math.sqrt((x - x1)**2 + (y - y1)**2).floor # Distance
      return nil if d == 0

      # Calculate Route Slope to avoid slope collisions
      s = ((x1 - x) == 0) ? 0 :  ((y1 - y) / (x1 - x))
      return nil if (@slopes[k].include?(s))
      @slopes[k] << s

      c = "%02d%02d" % [x1, y1]
      if (keys.include?(c) and !@routes.include?("#{k}#{c}"))
        a = center_of(k)
        b = center_of(c)
        @routes << "#{c}#{k}" # reverse look-up.
        route = "<!-- #{k} > #{c} --><line class='line#{d}' x1='#{a[0]}' y1='#{a[1]}' x2='#{b[0]}' y2='#{b[1]}' />"
      end
      return route
    end
    def build_routes
      routes = []
      keys = @volumes.map do |v|
        v[0..3]
      end
      paths = {
        "0"  => (-4..4).to_a, "1"  => (-4..3).to_a, "2"  => (-3..3).to_a,
        "3"  => (-3..2).to_a, "4"  => (-2..2).to_a, "-1" => (-3..4).to_a,
        "-2" => (-3..3).to_a, "-3" => (-2..3).to_a,
        "-4" => (-2..2).to_a,
      }
      @slopes = {}
      keys.each do |k|
        x = k[0..1].to_i
        y = k[2..3].to_i
        @slopes[k] = []
        [1,-1,2,-2,3,-3,4,-4].to_a.each do |n| # Ys
          [1,-1,2,-2,3,-3,4,-4].to_a.each do |m|
            routes << calc_route(x,m,y,n)
          end
        end
      end
      routes.compact.join("\n")
    end
    def convert
      from_file

      svg = []
      svg << header
      svg << tract_marks
      svg << hex_grid
      svg << build_routes
      svg << @volumes.map {|v| world(v) }
      svg << volumes
      svg << frame
      svg << footer
      File.open(@svg_filename,'w').write(svg.flatten.join("\n"))
    end
    def footer
      return "</svg>"
    end
    def header
      return<<-EOS
<?xml version="1.0" standalone="no"?>
  <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN"
    "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg width="#{@width}px" height="#{@height}px" version="1.1" xmlns="http://www.w3.org/2000/svg">
  <desc>Subsector Map Grid</desc>
  <style>
    svg {
      fill: #FFF;
    }
    text {
      text-anchor: middle;
      fill: #567;
      font: 8px sans-serif;
    }
    text.tract {
      text-anchor: left;
      fill: #eed;
      font: 120px sans-serif;
    }
    text.namestamp {
      font-size: 13px;
    }
    text.symbol {
      font-size: 14px;
      fill: #222;
    }
    g.volumes text {
      fill: #DDD;
    }
    line {
      opacity: 0.5;
    }
    line.line1 {
      stroke: #666;
      stroke-width:4;
    }
    line.line2 {
      stroke: #66C;
      stroke-width:3;
    }
    line.line3 {
      stroke: #C60;
      stroke-width:2;
      xstroke-dasharray: 5, 5, 1, 5;
      display:none;
    }
    line.line4 {
      stroke: #C00;
      stroke-width:1;
      stroke-dasharray: 2,6;
      stroke-linecap: round;
      display:none;
    }
    polyline {
      fill: none;
      stroke: #DDD;
      stroke-width: 1;
    }
    g.gas-giant {
      stroke: #034;
    }
    g.gas-giant circle {
      fill:   #034;
      stroke: #034;
      stroke-width:1;
    }
    g.gas-giant ellipse {
      stroke: #034;
      stroke-width: 1;
    }
    circle {
      fill: #222;
      stroke: #fff;
      stroke-width: 1;
    }
    .zone {
      fill: none;
      stroke: #B90;
      stroke-width: 3;
      stroke-dasharray: 3,6;
    }
  </style>
  <rect width='#{@width}' height='#{@height}' />
      EOS
    end
    def center_of(locx)
      column = locx[0..1].to_i
      row    = locx[2..3].to_i
      x      = @side + ((column - 1) * @side * 1.5) # 40 + ((COL - 1) * 60 )
      y      = (row - 1) * @side * @factor + (@side * @factor / (1 + (column % 2)))
      return [x.tweak,y.tweak]
    end
    def star_coords(r1,r2,points)
      pangle = 2*@@pi/points
      sangle = @@pi/points
      oangle = @@pi/-2
      coords = []
      points.times do |j|
        coords << [r1 * Math::cos(pangle * j + oangle), r1 * Math::sin(pangle * j + oangle)]
        coords << [r2 * Math::cos((pangle * j) + sangle + oangle), r2 * Math::sin((pangle * j) + sangle + oangle)]
      end
      return coords
    end
    def world(volume)
      # TAB 0 - World Details
      # 0. Location
      # 1. UWP
      # 2. Temp
      # 3. NSG (Features)
      # 4. Travel Zone
      # TAB 1 - Trade Codes
      # TAB 2 - Factions
      # TAB 3 - Name
      #1101 A505223-B  ..G.. »·IC,Lo,Va       »N,O,N   »·G0V  »Omivarium
      details, trades, factions, star, name = volume.split(/\t/)

      locx, uwp, temp, nsg, zone = details.split(/\s+/)

      spaceport = uwp[0]
      size      = uwp[1]
      c         = center_of(locx) # get Location's x,y Coordinates
      curve = @side / 2

      output =  "<!-- Volume: #{volume.strip.gsub(/\t/,' // ')} -->\n"
      output +=  (size == '0') ? draw_belt(c) : draw_planet(c,uwp)
      output += "    <text class='spaceport' x='#{c[0].to_i}' y='#{(c[1] + @side / 2).to_i}'>#{spaceport.strip}</text>\n"
      output += "    <text x='#{c[0].to_i}' y='#{(c[1]+(@side/1.3)).to_i}'>#{uwp.strip}</text>\n"
      output += "    <text x='#{c[0].to_i}' y='#{(c[1]-(@side/2.1)).to_i}'>#{name.strip}</text>\n"
      unless zone == '..'
        style = zone + '_zone'
        output += "    <path class='zone' d='M #{(c[0] - curve/2).to_i} #{(c[1] - (curve/1.4)).to_i} a #{curve} #{curve} 0 1 0 20 0' />\n"
      end
      output += navy_base(c)  if nsg.include?('N')
      output += scout_base(c) if nsg.include?('S')
      output += gas_giant(c)  if nsg.include?('G')
      output += consulate(c)  if nsg.include?('C')
      output += pirates(c)    if nsg.include?('P')
      output += stars(c,star)
      output

    end
    def stars(c,stars)
      output = ''
      x = (c[0]+(@side/1.8)).tweak + 2
      y = (c[1]-(@side/3)).tweak + 3
      stars.split('/').each do |star|
        output += "    <text x='#{x.to_i}' y='#{y.to_i}'>#{star[0..1].strip}</text>\n"
        x += 3
        y += 7
      end
      output
    end
    def draw_planet(c,w)
      k = (w[3] == '0') ? 'Desert' : 'Planet'
       "    <circle class='planet' cx='#{c[0].to_i}' cy='#{c[1].to_i}' r='#{(@side/7).to_i}' />\n"
    end
    def draw_belt(c)
      output = "    <g class='belt'>\n"
      7.times do
        x = c[0] + Random.rand(@side/3) - @side/6
        y = c[1] + Random.rand(@side/3) - @side/6
        output += "      <circle class='belt' cx='#{x.to_i}' cy='#{y.to_i}' r='#{(@side/15).tweak}' />\n"
      end
      output + "    </g>\n"
    end
    def frame(k='Frame')
      style = k.to_sym
      z = 0; w = @width.to_i - 0; h = @height.to_i - z;
      "    <polyline class='frame' points='#{z},#{z} #{w},#{z} #{w},#{h} #{z},#{h} #{z},#{z}' />"
    end
    def tract_marks
      height = (@height / 4).floor
      width  = (@width / 4).ceil
      # width -= 2

      output = ''
      letters = ('A'..'P').to_a
      5.times do |r|
        h1 = ((height.floor * r) - (8*r)).to_i; h2 = (h1 + height - 8).to_i
        w2 = 0
        4.times do |c|
          w1 = w2.to_i; w2 += (width - [-4,4,5,-4][c]).to_i
          output += "    <text class='tract' x='#{w1 + 70}' y='#{h1 + 110}'>#{letters.shift}</text>\n"
          output += "    <polyline class='tract' points='#{w1},#{h1} #{w2},#{h1} #{w2},#{h2} #{w1},#{h2} #{w1},#{h1}' />\n"
          # raise output
        end
      end
      output += namestamp
      return output
    end
    def volumes
      output = "<g class='volumes'>"
      (@rows+2).times do |r|
        (@columns+1).times do |c|
          x = @side + ((c-1) * @side * 1.5)
          y = (c % 2 == 1) ? (r-1) * @side * @factor + (0.2 * @side) : (r-1) * @side * @factor + @hex[:side_h]+ (0.2 * @side)
          output += "<text x='#{x.to_i}' y='#{y.to_i}'>%02d%02d</text>\n" % [c,r]
        end
      end
      output += "</g>"
    end
    def polygon(x, y, sx, sy, sides=4)
      polygon = star_coords(sx, sy, sides).map { |c| "#{(x + c[0]).to_i},#{(y.tweak+c[1]).to_i}" }
      "    <polygon points='#{polygon.join(' ')}' />\n"
    end
    def gas_giant(c)
      x = (c[0]+(@side/1.8)).tweak; y = (c[1]+(@side/3)).tweak;
      return<<-GIANT
      <g class='gas-giant'><!-- Has Gas Giant -->
        <ellipse cx='#{x.to_i}' cy='#{y.to_i}' rx='#{(@side/(@mark * 0.5)).to_i}' ry='#{(@side/@mark * 0.3).tweak}' />
        <circle cx='#{x.to_i}' cy='#{y.to_i}' r='#{(@side/(@mark * 1.2)).to_i}' />
      </g>
      GIANT
    end
    def pirates(c);
        return "<!-- Pirates --><text class='symbol' x='#{(c[0]-(@side/3.1)).to_i}' y='#{(c[1]+(@side/7)).to_i}'>\u2620</text>\n"
    end
    def consulate(c);
        return "<!-- Consulate --><text class='symbol' x='#{(c[0]-(@side/1.5)).to_i}' y='#{(c[1]+(@side/7)).to_i}'>\u2691</text>\n"
    end
    def scout_base(c);
        return "<!-- Scout Base --><text class='symbol' x='#{(c[0]-(@side/1.8)).to_i}' y='#{(c[1]+(@side/2.4)).to_i}'>\u269C</text>\n"
      '<!-- SB -->' + polygon(c[0]-(@side/1.8),c[1]+(@side/3.7), @side/(@mark/2), @side/@mark, 3);
    end
    def navy_base(c);
      return "<!-- Navy Base --><text class='symbol' x='#{c[0]-(@side/1.8)}' y='#{c[1]-(@side/6)}'>\u2693</text>\n"
      '<!-- NB -->' +polygon(c[0]-(@side/1.8), c[1]-(@side/3.7), @side/(@mark/2), @side/@mark, 5);
    end
    def hex_grid; (@rows * 3 + 2).times.map { |j| hex_row((j/2).floor, (j % 2 != 0)) };
    end
    def namestamp
      return "<text class='namestamp' x='30' y='2800'>#{@name}</text>"
    end
    def hex_row(row, top=false)
      ly = (row * 2 * @hex[:side_h]) + @hex[:side_h]
      points = []
      x = 0; y = 0
      (@columns/2).ceil.times do |j|
        x = j * @side * 3
        y = ly
        points << "#{x.to_i},#{y.to_i}"

        x += @hex[:side_w]
        y = (top) ? y - @hex[:side_h] : y + @hex[:side_h]
        points << "#{x.to_i},#{y.to_i}"

        x += @hex[:width]
        points << "#{x.to_i},#{y.to_i}"

        x += @hex[:side_w]
        y = (top) ? y + @hex[:side_h] : y - @hex[:side_h]
        points << "#{x.to_i},#{y.to_i}"

        x += @hex[:width]
        points << "#{x.to_i},#{y.to_i}"
      end
      x += @hex[:side_w]
      y = (top) ? y - @hex[:side_h] : y + @hex[:side_h]
      points << "#{x.to_i},#{y.to_i}"
      "    <polyline points='#{points.join(' ')}' />"
    end
  end
end
