module Astromapper
  module Builder
    class Volume < Astromapper::Builder::Base

      attr_accessor :gas_giant, :name
      attr_reader   :column, :row

      # Genre-driven bias toward warm, long-lived (F/G/K) primaries, so that
      # settled space trends toward scientifically-plausible habitable stars.
      # normal: gonzo, no skew; opera: moderate; firm: strong (and firm also
      # strips population from marginal worlds, compounding the effect).
      # Genre stellar model: opera uses the T5 spectral table (Star#initialize), so its
      # bias is ignored. normal and firm use the M-heavy base; firm is the *realistic*
      # M-dwarf galaxy (bias 0), so no F/G/K skew.
      STAR_BIAS = { 'normal' => 0, 'opera' => 0, 'firm' => 0 }.freeze

      def initialize(c,r)
        @name   = (config['named']) ? Astromapper.names.sample : "%02d%02d" % [c,r]
        @column = c
        @row    = r
        @star   = Star.new(self, star_dm: STAR_BIAS[config['genre'].to_s.downcase] || 0)
        [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2][toss(2,0)].times do |i|
          @star.companions = Star.new(self, @star,i)
        end
      end

      def to_ascii
        w = @star.world
        sumy = "%s %s %s %s %s\t%-15s\t%-8s\t%s\t%-15s\t%s\t%s" % [location, w.uwp, w.temp, w.bases, w.travel_code, w.trade_codes.join(','), w.factions.join(','), @star.crib, @name, w.extensions, w.native]
        sumy += @star.orbits_to_ascii
        return sumy
      end

      # One T5 Second Survey (TravellerMap) tab-delimited row for this system.
      def to_tab(sector, allegiance)
        w = @star.world
        ss     = (('A'.ord) + ((@row - 1) / 10) * 4 + ((@column - 1) / 8)).chr
        belts  = @star.orbits.count { |o| o.kid == 'B' }
        gg     = @star.orbits.count { |o| o.kid == 'G' }
        pmul   = w.popx.to_i.zero? ? 0 : (1 + rand(9))     # population multiplier (1-9)
        pbg    = "%d%d%d" % [pmul, [belts, 9].min, [gg, 9].min]
        worlds = [@star.orbits.count { |o| o.kid == 'W' }, 1].max
        zone   = { 'RZ' => 'R', 'AZ' => 'A' }[w.travel_code] || ''
        ix = ex = cx = ''
        if w.ix
          ix = "{ %d }" % w.ix
          ex = "(%s%s%s%+d)" % [w.ex[:res].hexd, w.ex[:lab].hexd, w.ex[:inf].hexd, w.ex[:eff]]
          cx = "[%s%s%s%s]" % [w.cx[:homo].hexd, w.cx[:acc].hexd, w.cx[:str].hexd, w.cx[:sym].hexd]
        end
        [sector, ss, location, @name, w.uwp, w.t5_bases, w.trade_codes.join(' '),
         zone, pbg, allegiance, @star.t5_stars, ix, ex, cx, '', worlds, w.ru].join("\t")
      end

      def empty?
        return true if @star.world.nil? or @star.world.empty? or !@star.world?
      end

      def location
        "%02d%02d" % [@column,@row]
      end
    end
  end
end