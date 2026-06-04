module Astromapper
  module Builder

    # Class Orbit
    class Orbit < Astromapper::Builder::Base
      attr_accessor :id, :kid, :au, :port, :orbit_number, :xsize, :size
      def initialize(star,orbit_number,companion=nil)
        @orbit_number = orbit_number.round
        @au = star.orbit_to_au(orbit_number)
        @kid   = '.'
        @star  = star
        @atmo  = 0
        @moons = 0
        @h20   = 0
        @popx  = 0
        @tek   = 0
        @port  = 'X'
        @govm  = 0
        @law   = 0
        @xsize = '.'
        begin
          @zone = case
            when @au < @star.biozone[0] then -1 # Inside
            when @au > @star.biozone[1] then 1  # Outside
            else 0
          end
          @distant = (@au > @star.biozone[1] * 10)
        rescue
          # There is no biozone, so all is "inside"
          @zone = -1
          @distant = 1000
        end
      end
      def uwp
        '.......-.' # "%s%s%s%s%s%s%s-%s" % [port, @size.hexd, @atmo.hexd, @h20.hexd, @popx.hexd, @govm.hexd, @law.hexd, @tek.hexd]
      end
      def port
        @port || 'X'
      end
      def populate
        case
          when @au > @star.outer_limit then return self
          when limit? then return self
          when inner? then populate_inner
          when outer? then populate_outer
          else populate_biozone
        end
      end
      def populate_biozone
        # When 'always_inhabited' is enabled (the default), the biozone orbit is
        # guaranteed to be a habitable World so every system has a mainworld.
        # Disable it to let the biozone occasionally roll up a gas giant instead.
        return World.new(@star, @orbit_number) if config['always_inhabited'] != false
        roll = toss(2,0)
        return (roll < 12) ? World.new(@star, @orbit_number) : GasGiant.new(@star, @orbit_number)
      end
      def populate_inner
        roll = toss(2,0)
        return case
          when roll < 5 then self
          when (5..6) === roll   then Hostile.new(@star, @orbit_number)
          when (7..9) === roll   then Rockball.new(@star, @orbit_number)
          when (10..11) === roll then Belt.new(@star, @orbit_number)   
          else GasGiant.new(@star, @orbit_number)
        end
      end
      def populate_outer
        roll = toss(1,0)
        roll += 1 if distant?
        return case
          when roll == 1 then Rockball.new(@star, @orbit_number)
          when roll == 2 then Belt.new(@star, @orbit_number)
          when roll == 3 then self
          when (4..7) === roll then GasGiant.new(@star, @orbit_number)
          else Rockball.new(@star, @orbit_number)
        end
      end
      def to_s
        @kid
      end
      def to_ascii
        bio = (@zone == 0 ) ? '*' : ' '
        bio = '-' if @au > @star.outer_limit
        output = "  -- %2s. %s  %s // %s // %4.1f au" % [@orbit_number + 1, bio, @kid, self.uwp, @au]
        @moons.each {|m| output += m.to_ascii} unless @moons.nil? or @moons == 0
        output
        
      end
      def period; (@au * 365.25).round(2); end
      def km; return (150000000 * @au).to_i; end
      def radii; (@au * 200).to_i; end
      def limit?;   return @au < @star.limit ; end
      def inner?;   return @zone < 0; end
      def outer?;   return @zone > 0; end
      def biozone?; return @zone == 0; end
      def distant?; @distant; end
    end # End Orbit

    class Companion<Orbit
      def initialize(star,orbit_number,companion)
        @star = star
        @comp = companion
        super
        @kid = 'S'
      end
      def uwp
        "%-9s" % [@comp.classification]
      end
    end
    class Belt<Orbit
      def initialize(star,orbit_number)
        super
        @kid = 'B'
      end
      def uwp
        'XR00000-0'
      end
    end


    class Planet<Orbit
      def initialize(star,orbit_number)
        super
        # Establish a size before spawning moons; Moon sizing reads @planet.size,
        # which would otherwise be nil during construction. Subclasses that set a
        # more specific @size (e.g. Terrestrial) do so after calling super.
        @size = toss if @size.nil? or @size == 0
        @moons = make_moons(toss(1,3))
      end
      def make_moons(c)
        moons = {}
        c.times { |i|
          m = Moon.new(self,i)
          moons["#{m.orbit}"] = m
        }
        moons.values.sort{ |a,b| a.orbit <=> b.orbit } unless @moons.size < 2
      end
      def uwp
        "%s%s%s%s%s%s%s-%s" % [port, @size.hexd, @atmo.hexd, @h20.hexd, @popx.hexd, @govm.hexd, @law.hexd, @tek.hexd]
      end
    end

    class Rockball<Planet
      def initialize(star,orbit_number)
        super
        @kid = 'R'
      end
    end

    class Hostile<Planet
      def initialize(star,orbit_number)
        super
        @atmo = [10,11,12,13,14].sample
        @h20  = (toss(2,4)).max(10)   # exotic-atmosphere worlds can have (acid) seas; 0-A
        @kid  = 'H'
      end
    end

    class GasGiant<Planet
      def initialize(star,orbit_number)
        super
        @xsize = (toss(1,0) < 4) ? 'L' : 'S'
        moons = toss(2,0)
        moons = (moons - 4).whole if @xsize == 'S'
        @moons = make_moons(moons)
        @kid = 'G'
      end
      def uwp
        (@xsize == 'S') ? 'Small GG ' : 'Large GG '
      end
    end

    class Terrestrial<Planet  
      def initialize(star,orbit_number)
        super
        @kid       = 'R'
        
        # Size / Atmosphere / Hydrographics — Traveller 5 WorldGen (StSAHPGL-T).
        # Size = 2D-2 (0 = planetoid belt); a roll of 10 rerolls 1D+9 toward F.
        @size = toss()
        @size = 9 + 1.d6 if @size == 10
        # Atmosphere = Flux + Size, clamp 0-F; a sizeless world has none.
        @atmo = @size.zero? ? 0 : (flux + @size).whole.max(15)
        # Hydrographics = Flux + Atmosphere, max A; dry when tiny or thin/dense.
        @h20  = flux + @atmo
        @h20 -= 4 if (@atmo < 2 or @atmo > 9)
        @h20  = 0 if @size < 2
        @h20  = @h20.whole.max(10)

        # Climate — Traveller 5, from the world's position in the Habitable Zone.
        @temp = climate

        # Adjust Atmosphere and Hydrographics when not Normal. MgT p. 180.
        if (%w{opera firm}.include?(config['genre'].downcase))
          @atmo = case
            when (@size < 3 or (@size < 4 and @atmo < 3)) then 0
            when ([3,4].include?(@size) and (3..5).include?(@atmo)) then 1
            when ([3,4].include?(@size) and @atmo > 5) then 10
            else @atmo
          end
          @h20 -= 6 if (((3..4).include?(@size) and @atmo == 'A' ) or @atmo < 2)
          @h20 -= 4 if ([2,3,11,12].include?(@atmo))
          @h20  = @h20.whole
        end
      end

      # Traveller 5 climate, from the Habitable Zone Variance (a Flux roll, page 432):
      # HZ−1 = Hot, HZ = Temperate, HZ+1 = Cold; orbits 0–1 are tidally locked = Twilight.
      #   T Temperate · H Hot · C Cold · Tz Twilight · Lk Locked
      def climate
        return 'Tz' if @orbit_number <= 1
        #            Flux: -6 -5 -4 -3 -2 -1  0 +1 +2 +3 +4 +5 +6
        variance = [-2,-1,-1,-1, 0, 0, 0, 0, 0, 1, 1, 1, 2][flux + 6]
        return 'H' if variance <= -1
        return 'C' if variance >=  1
        'T'
      end
    end # End Terrestrial

    #===============
    # Big Dea
    # 
    # 
    #
    #
    #
    #
    #
    #

   class World<Terrestrial
      attr_accessor :factions, :temp, :gas_giant, :ix, :ex, :cx, :ru, :native
      def initialize(star,orbit_number)
        super
        
        @port_roll = toss(2,0)
        
        @kid = 'W'
        # Population = 2D-2; a roll of 10 rerolls 9+1D toward F. T5 WorldGen.
        @popx = toss()
        @popx = 9 + 1.d6 if @popx == 10
        if ('firm' == config['genre'].downcase)
          @popx -= 1 if (@size < 3 or @size > 9)
          @popx += [-1, -1, -1, -1, -1, 1, 1, -1, 1, -1, -1, -1, -1, -1, -1, -1][@atmo]
          @port_roll = (@port_roll + 7 - @popx.whole).whole # T5: higher pop -> lower roll -> better port
        end
        @popx = @popx.whole.max(15) # population ceiling is F
        # Short-lived, high-UV stars (F and hotter) can't host large native populations —
        # only frontier colonies. Cap their worlds at colony size (6).
        @popx = @popx.max(6) if %w{O B A F}.include?(@star.type)
        # A naturally-habitable (non-colony) world needs a comfortable gravity band: enough
        # to hold a shielding atmosphere/magnetosphere (~0.4 g, above Mars), but not so much
        # it crushes its inhabitants (~1.5 g). Outside that, only domed/hardy colonies live.
        @popx = @popx.max(6) unless (0.4..1.5).cover?(gravity)

        # Government = Flux + Pop (ceiling F); Law = Flux + Gov (ceiling J). T5 WorldGen.
        @govm = (flux + @popx).whole.max(15)
        @law  = (flux + @govm).whole.max(18)

        # Identify Factions. MgT p. 173
        fax_r = 1.d3.max(3)
        fax_r += 1 if [0,7].include?(@law)
        fax_r -= 1 if @law > 9
        rolls = [toss(2,0),toss(2,0),toss(2,0),toss(2,0),toss(2,0)]
        @factions = (@popx == 0) ? [] : fax_r.times.map { |r| %w{O O O O F F M M N N S S P}[rolls.shift] }
        
        # Technology die modifiers — Traveller 5 (TL = 1D + mods).
        tek_dm  = { 'A' => 6, 'B' => 4, 'C' => 2, 'D' => 0, 'E' => 0, 'F' => 1, 'X' => -4}[port] || 0
        #            0 1 2 3 4 5 6 7 8 9 A  B  C  D  E  F
        tek_dm += [2,2,1,1,1,0,0,0,0,0,0,0,0,0,0,0][@size]  # Siz 0,1=+2; 2,3,4=+1
        tek_dm += [1,1,1,1,0,0,0,0,0,0,1,1,1,1,1,1][@atmo]  # Atm 0-3=+1; A-F=+1
        tek_dm += [0,0,0,0,0,0,0,0,0,1,2][@h20]             # Hyd 9=+1; A=+2
        tek_dm += [0,1,1,1,1,1,0,0,0,2,4,4,4,4,4,4][@popx]  # Pop 1-5=+1; 9=+2; A+=+4
        tek_dm += [1,0,0,0,0,1,0,0,0,0,0,0,0,-2,0,0][@govm] # Gov 0,5=+1; D=-2
        @tek = (toss(1,0) + tek_dm).whole   # T5: TL = 1D + mods (floored at 0)
        # Optional cap for those who want to limit technology, then a single UWP digit (0-F).
        @tek = @tek.max(config['tech_cap']) unless config['tech_cap'].nil?
        @tek = @tek.max(15)
        @law = @govm = @tek = 0 if @popx == 0
        
        # Bases — Traveller 5 (page 432). Each rolls 2D against a starport threshold.
        # Naval/Scout are exact; Depot/Way Station are "Possible" (full Chart F-B), so the
        # thresholds below are a conservative approximation.
        naval = (port == 'A' && 2.d6 <= 6) || (port == 'B' && 2.d6 <= 5)
        scout = (port == 'A' && 2.d6 <= 4) || (port == 'B' && 2.d6 <= 5) ||
                (port == 'C' && 2.d6 <= 6) || (port == 'D' && 2.d6 <= 7)
        depot = %w{A B}.include?(port)   && 2.d6 <= 3   # approximate
        way   = %w{A B C}.include?(port) && 2.d6 <= 4   # approximate
        @base = {
          'Naval' => naval ? 'N' : '.',
          'Scout' => scout ? 'S' : '.',
          'Depot' => depot ? 'D' : '.',
          'Way'   => way   ? 'W' : '.',
        }
      end
      def travel_code
        # Travel zones. T5 leaves these to the referee; this auto-assigns a default:
        # Red for the most oppressive/controlled worlds, Amber for caution.
        return 'RZ' if (@law >= 15 or @govm >= 15)
        return 'AZ' if (@atmo > 9 or [0,7,10].include?(@govm) or @law == 0 or (9..14).include?(@law))
        '..'
      end

      # Traveller 5 Extensions (Ix / Ex / Cx). Computed after the system is built,
      # since Resources depends on the system's gas-giant and planetoid-belt counts.
      def build_extensions(gas_giants = 0, belts = 0)
        tc = trade_codes

        # Importance Extension (Ix) — T5 WorldGen page 435.
        @ix  = 0
        @ix += 1 if %w{A B}.include?(port)
        @ix -= 1 if %w{D E X}.include?(port)
        @ix += 1 if @tek >= 10                                   # TL A or more
        @ix -= 1 if @tek <= 8                                    # TL 8 or less
        @ix += (tc & %w{Ag Hi In Ri}).size                      # per Ag Hi In Ri
        @ix -= 1 if @popx <= 6                                   # Pop 6 or less
        @ix += 1 if @base['Naval'] == 'N' && @base['Scout'] == 'S'  # Naval AND Scout
        @ix += 1 if @base['Way'] == 'W'                         # Way Station

        # Economic Extension (Ex) — Resources, Labor, Infrastructure, Efficiency; RU.
        res = 2.d6
        res += gas_giants + belts if @tek >= 8                  # GG + Belts only at TL 8+
        lab = (@popx - 1).whole                                 # Labor = Pop - 1 (min 0)
        inf = if (tc & %w{Ba Di Lo}).any? then 0
              elsif tc.include?('Ni')      then 1.d6
              else (2.d6 + @ix).whole end                       # min 0
        eff = flux                                              # Efficiency = Flux (may be negative)
        nz  = ->(v) { v.zero? ? 1 : v }                         # 0 -> 1 for RU only
        @ru = nz.(res) * nz.(lab) * nz.(inf) * nz.(eff)
        @ex = { res: res, lab: lab, inf: inf, eff: eff }

        # Cultural Extension (Cx) — Homogeneity, Acceptance, Strangeness, Symbols.
        # T5: "For all values, less than 1 = 1."
        min1 = ->(v) { v < 1 ? 1 : v }
        @cx  = {
          homo: min1.(@popx + flux),
          acc:  min1.(@popx + @ix),
          str:  min1.(5 + flux),
          sym:  min1.(@tek + flux),
        }

        @native = native_status
        self
      end

      # Native Intelligent Life / Native Status — T5 WorldGen page 436 (NIL).
      # Default is a HUMAN-ONLY universe: every population is a human settlement, so worlds
      # are simply Settled (established) or a Colony (frontier). Set `sophonts: varied` in
      # the config to allow native alien sophonts (Native = evolved here; Exotic = non-human
      # transplants on a world that couldn't grow native intelligent life).
      def native_status
        if config['sophonts'].to_s.downcase == 'varied'
          if @popx >= 7
            return 'Exotic' if @atmo <= 1
            return 'Native'
          end
          return 'Colony' if (1..6).include?(@popx)
          return ''
        end
        # Human-only (default)
        return 'Settled' if @popx >= 7
        return 'Colony'  if (1..6).include?(@popx)
        ''
      end

      # Formatted extensions for the system line: { +n } (RLI±E) [HASS]
      def extensions
        return '' if @ix.nil?
        ix = "{ %+d }" % @ix
        ex = "(%s%s%s%+d)" % [@ex[:res].hexd, @ex[:lab].hexd, @ex[:inf].hexd, @ex[:eff]]
        cx = "[%s%s%s%s]" % [@cx[:homo].hexd, @cx[:acc].hexd, @cx[:str].hexd, @cx[:sym].hexd]
        "%s %s %s RU:%d" % [ix, ex, cx, @ru]
      end
      # Surface gravity (g) by Size. Extended to cover T5 sizes B-F (super-terrestrials).
      def gravity
        #              0   1    2    3    4    5   6   7   8   9    A   B   C   D   E   F
        @gravity ||= [0,0.05,0.15,0.25,0.35,0.45,0.7,0.9,1.0,1.25,1.4,1.6,1.9,2.2,2.5,2.8][@size]
        @gravity
      end
      def bases
        return [@base['Naval'],@base['Scout'],@gas_giant,@base['Depot'],@base['Way']].join('')
      end
      def popx; @popx; end
      # Bases for the T5SS Bases column: the gas-giant marker is dropped (it lives
      # in PBG, not Bases).
      def t5_bases
        b = bases
        (b[0] + b[1] + b[3] + b[4]).delete('.')
      end
      def port
        # Traveller 5 orientation (page 432): low roll = best. 2-4 A, 5-6 B, 7-8 C, 9 D, 10-11 E, 12 X.
        %w{A A A A A B B C C D E E X}[@port_roll.whole.max(12)]
      end
      def empty?
        (uwp.include?('X000000'))
      end
      # Trade Classifications — Traveller 5 WorldGen TCS table (page 434).
      # Political and Special TCs are referee-assigned (not generated). Lk/Tz/Ho/Co
      # are climate descriptors, included here as the T5 page lists them.
      def trade_codes
        a, h, s, p, g, l = @atmo, @h20, @size, @popx, @govm, @law
        code = []
        # Planetary
        code << 'As' if (s == 0 and a == 0 and h == 0)
        code << 'De' if ((2..9).include?(a) and h == 0)
        code << 'Fl' if ([10,11,12].include?(a) and (1..10).include?(h))
        code << 'Ga' if ([6,7,8].include?(s) and [5,6,8].include?(a) and [5,6,7].include?(h))
        code << 'He' if ([3,4,5,9,10,11,12].include?(s) and [2,4,7,9,10,11,12].include?(a) and [0,1,2].include?(h))
        code << 'Ic' if ([0,1].include?(a) and (1..10).include?(h))
        code << 'Oc' if ([10,11,12].include?(s) and h == 10)
        code << 'Va' if (a == 0)
        code << 'Wa' if ([5,6,7,8,9].include?(s) and h == 10)
        # Population
        code << 'Ba' if (p == 0 and g == 0 and l == 0 and %w{E X}.include?(port))
        code << 'Lo' if ((1..3).include?(p))
        code << 'Ni' if ((4..6).include?(p))
        code << 'Ph' if (p == 8)
        code << 'Hi' if (p >= 9)
        # Economic
        code << 'Pa' if ((4..9).include?(a) and (4..8).include?(h) and [4,8].include?(p))
        code << 'Ag' if ((4..9).include?(a) and (4..8).include?(h) and (5..7).include?(p))
        code << 'Na' if ((0..3).include?(a) and (0..3).include?(h) and p >= 6)
        code << 'Pi' if ([0,1,2,4,7,9].include?(a) and [7,8].include?(p))
        code << 'In' if ([0,1,2,4,7,9].include?(a) and p >= 9)
        code << 'Po' if ((2..5).include?(a) and (0..3).include?(h))
        code << 'Pr' if ([6,8].include?(a) and [5,9].include?(p))
        code << 'Ri' if ([6,8].include?(a) and (6..8).include?(p))
        # Technology (not on the T5 TCS page; conventional)
        code << 'Ht' if (@tek > 12)
        code << 'Lt' if (@tek < 6)
        # Climate descriptors (HZ-derived)
        code << 'Tz' if @temp == 'Tz'
        code << 'Lk' if @temp == 'Lk'
        code << 'Ho' if @temp == 'H'
        code << 'Co' if @temp == 'C'
        code << 'Tr' if (@temp == 'H' and [6,7,8,9].include?(s) and (4..9).include?(a) and (3..7).include?(h))
        code << 'Tu' if (@temp == 'C' and [6,7,8,9].include?(s) and (4..9).include?(a) and (3..7).include?(h))
        code
      end
    end # End World (Mainworld)

    class Moon < Astromapper::Builder::Base
      attr_accessor :orbit, :size, :h20
      @@orbits = { 'C' => (1..14).to_a, 'R' => [1,1,1,2,2,3] }
      @@orbits['F'] = @@orbits['C'].map{|c| c * 5}
      @@orbits['E'] = @@orbits['C'].map{|c| c * 25}
      
      def initialize(planet,i=0)
        @planet = planet
        @popx = 0
        @law  = 0
        @tek  = 0
        @govm = 0
        @size = case
          when @planet.xsize == 'L' then toss(2,4)
          when @planet.xsize == 'S' then toss(2,6)
          else @planet.size - toss(1,0)
        end
        orbit = toss(2,i)
        @orbit = (case
          when (@size < 1) then @@orbits['R'][toss(1,1)]
          when (orbit == 12 and @planet.xsize == 'L') then @@orbits['E'][toss(2,0)]
          when (orbit < 8) then @@orbits['C'][toss(2,0)]
          when (orbit > 7) then @@orbits['C'][toss(2,0)]
          else 0
        end).whole
        @h20 = (case
          when (@planet.inner?) then 0
          when (@size == 0)    then 0
          when (@planet.outer?) then toss(2,4)
          when (@planet.biozone?) then toss(2,7)
          else 0
        end).whole
        @atmo = toss(2,7) + @size
        @atmo = (case
          when (@size == 0) then 0
          when (@planet.inner?) then @atmo - 4
          when (@planet.outer?) then @atmo - 4 
          else 0
        end).whole
      end
      def to_ascii
        "\n%28s/  %3d rad. %s" % ['', @orbit, uwp]
      end
      def uwp
        size = case
          when @size < 0 then 'S'
          when @size == 0 then 'R'
          else @size.hexd
        end
        # size = (@size == 0) ? 'R' : @size.hexd
        "%s%s%s%s%s%s%s" % ['X', size,@atmo.hexd,@h20.hexd,@popx.hexd,@govm.hexd,@law.hexd]
      end
    end # End Moon

  end # End Builder
end # End Astromapper
