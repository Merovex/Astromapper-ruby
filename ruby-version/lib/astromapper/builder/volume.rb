module Astromapper
  module Builder
    class Volume < Astromapper::Builder::Base

      attr_accessor :gas_giant, :name

      # Genre-driven bias toward warm, long-lived (F/G/K) primaries, so that
      # settled space trends toward scientifically-plausible habitable stars.
      # normal: gonzo, no skew; opera: moderate; firm: strong (and firm also
      # strips population from marginal worlds, compounding the effect).
      STAR_BIAS = { 'normal' => 0, 'opera' => 2, 'firm' => 4 }.freeze

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
        sumy = "%s %s %s %s %s\t%-15s\t%-8s\t%s\t%s" % [location, w.uwp, w.temp, w.bases, w.travel_code, w.trade_codes.join(','), w.factions.join(','), @star.crib, @name]
        sumy += @star.orbits_to_ascii
        return sumy
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