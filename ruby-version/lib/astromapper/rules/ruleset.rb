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

      # Human-facing name (the YAML `name:` field), falling back to the file slug.
      def title
        @data['name'] || @name
      end

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
        new(name, data).validate!
      end

      # Child keys win. A child key with a trailing "!" replaces the parent value
      # wholesale instead of deep-merging — needed when a ruleset has a *different*
      # set (e.g. Cepheus trade codes), not additions to the parent's.
      def self.deep_merge(a, b)
        result = a.dup
        b.each do |k, bv|
          if k.to_s.end_with?('!')
            result[k.to_s.chomp('!')] = bv
          elsif result[k].is_a?(Hash) && bv.is_a?(Hash)
            result[k] = deep_merge(result[k], bv)
          else
            result[k] = bv
          end
        end
        result
      end

      def initialize(name, data)
        @name = name
        @data = data
        @trade = (data['trade_codes'] || {}).transform_values { |cond| Expr.compile(cond) }
      end

      # Fail fast on a malformed ruleset (typo'd custom file, broken inheritance), with
      # a message that names every problem at once. Returns self so load can chain it.
      def validate!
        errors = []
        errors << "missing `hex` alphabet" unless @data['hex'].is_a?(String) && !@data['hex'].empty?
        %w[size atmo hydro pop gov law].each do |step|
          s = (@data['uwp'] || {})[step]
          errors << "uwp.#{step}: missing or has no `roll`" unless s.is_a?(Hash) && s['roll']
        end
        errors << "missing `starport.table`" unless @data.dig('starport', 'table').is_a?(Array)
        %w[extensions climate native].each { |slot| module_for(slot) }   # raises on a bad name
        raise "ruleset #{@name.inspect} is invalid:\n- #{errors.join("\n- ")}" unless errors.empty?
        self
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

      # Does a base roll qualify? T5 wants `roll <= threshold` (default); Cepheus and
      # classic Traveller want `>=`. Set `bases.op` in the ruleset to switch.
      def base_meets?(roll, threshold)
        Expr.compare(@data.dig('bases', 'op') || '<=', roll, threshold)
      end

      # Name of the code module wired to an algorithmic slot (extensions/climate/native).
      # Returns a bare name like "t5" or "none"; defaults to "t5" when unspecified. The
      # name is constrained to a word so it can only resolve to a `<slot>_<name>` method.
      def module_for(slot)
        name = (@data['modules'] || {})[slot].to_s.downcase
        name = 't5' if name.empty?
        raise "ruleset #{@name.inspect}: bad module name #{name.inspect} for #{slot}" unless name =~ /\A\w+\z/
        name
      end

      # Evaluate one UWP step (size, atmo, hydro, pop, gov, law) against `ctx` — a Hash
      # of the digits computed so far. Returns the digit; the caller stores it back into
      # ctx before the next step. Handles zero_when / roll / reroll / adjust / clamp.
      def uwp_step(name, ctx)
        spec = (@data['uwp'] || {})[name]
        raise "ruleset #{@name.inspect} has no UWP step #{name.inspect}" unless spec
        return 0 if spec['zero_when'] && expr("uwp/#{name}/zero", spec['zero_when']).call(ctx)
        val = expr("uwp/#{name}/roll", spec['roll']).call(ctx)
        if (rr = spec['reroll']) && expr("uwp/#{name}/rr?", rr['when']).call(ctx.merge(name => val))
          val = expr("uwp/#{name}/rr=", rr['with']).call(ctx.merge(name => val))
        end
        (spec['adjust'] || []).each_with_index do |a, i|
          next unless expr("uwp/#{name}/adj#{i}", a['when']).call(ctx.merge(name => val))
          val = a.key?('set') ? a['set'].to_i : val + a['delta'].to_i
        end
        if (cl = spec['clamp'])
          val = cl.first if val < cl.first
          val = cl.last  if val > cl.last
        end
        val
      end

      private

      # Compile-and-cache an Expr by a stable key, so each formula is parsed once.
      def expr(key, src)
        (@compiled ||= {})[key] ||= Expr.compile(src)
      end
    end
  end
end
