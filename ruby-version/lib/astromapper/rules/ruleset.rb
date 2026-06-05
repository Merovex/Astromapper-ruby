require 'yaml'
require_relative 'expr'

module Astromapper
  module Rules
    # A Ruleset is the data-driven definition of a generation system (Traveller 5,
    # Cepheus, house rules…), loaded from `rules/<name>.yml`. For now it owns the
    # trade-classification table; UWP steps, starport/base tables, and the algorithmic
    # module hooks (extensions/climate/native) follow in later phases.
    class Ruleset
      # Built-in rulesets ship in ruby-version/rules; projects may add their own.
      BUILTIN_DIR = File.expand_path('../../../rules', __dir__)

      attr_reader :name, :data

      def self.search_dirs(root = nil)
        dirs = [BUILTIN_DIR]
        dirs.unshift(File.join(root, 'rules')) if root
        dirs
      end

      def self.load(name, root: nil)
        file = search_dirs(root).map { |d| File.join(d, "#{name}.yml") }.find { |f| File.file?(f) }
        raise "Unknown ruleset #{name.inspect} (looked in #{search_dirs(root).join(', ')})" unless file
        data = YAML.safe_load(File.read(file)) || {}
        if (base = data['extends'])               # shallow inheritance: child keys win
          data = deep_merge(load(base, root: root).data, data)
        end
        new(name, data)
      end

      def self.deep_merge(a, b)
        a.merge(b) { |_k, av, bv| av.is_a?(Hash) && bv.is_a?(Hash) ? deep_merge(av, bv) : bv }
      end

      def initialize(name, data)
        @name = name
        @data = data
        @trade = (data['trade_codes'] || {}).transform_values { |cond| Expr.compile(cond) }
      end

      # Trade classifications for a world. `ctx` is a Hash of UWP values keyed by name
      # (size, atmo, hydro, pop, gov, law, tech, port, temp). Order follows the YAML.
      def trade_codes(ctx)
        @trade.select { |_code, test| test.call(ctx) == true }.keys
      end

      # Starport letter for an orientation roll (clamped to the table). Deterministic.
      def starport(roll)
        table = @data.dig('starport', 'table') || []
        table[roll.to_i.clamp(0, table.size - 1)]
      end

      # Summed Tech-Level DM from the port map + per-digit arrays. Deterministic.
      def tech_dm(ctx)
        t = @data['tech_dm'] || {}
        dm = (t['port'] || {})[ctx['port']].to_i
        %w[size atmo hydro pop gov].each { |k| dm += ((t[k] || [])[ctx[k].to_i] || 0) }
        dm
      end

      # 2D threshold for a base at this starport, or nil if that port can't have it.
      def base_threshold(kind, port)
        (@data.dig('bases', kind) || {})[port]
      end
    end
  end
end
