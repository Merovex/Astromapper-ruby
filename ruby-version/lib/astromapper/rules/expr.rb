module Astromapper
  module Rules
    # A tiny, SANDBOXED evaluator for ruleset expressions — the engine behind
    # data-driven rules (trade-code conditions now; UWP step formulas later).
    # Supports: integer & string literals, named variables, dice (`2d6`, `1d6`,
    # `flux`), arithmetic (+ - * /), comparisons (== != < <= > >=), and booleans
    # (and / or / not), with parentheses.
    #
    # SECURITY: this is a hand-written recursive-descent parser/evaluator. It does
    # NOT call Ruby's `Kernel#eval` (or `instance_eval`/`send`) anywhere — only
    # arithmetic, comparisons, dice, and lookups in a caller-supplied context Hash
    # are possible. That is the whole point: ruleset files are data, so a malicious
    # `rules/*.yml` cannot execute code.
    #
    #   Expr.compile("atmo>=2 and atmo<=9 and hydro==0").call("atmo" => 5, "hydro" => 0) #=> true
    #   Expr.evaluate("2d6-2")                                                           #=> 0..10
    module Expr
      module_function

      # Compile once, call many — returns a lambda taking a context Hash.
      def compile(src)
        node = Parser.new(tokenize(src.to_s)).parse
        ->(ctx = {}) { node.call(ctx) }
      end

      # One-shot compile + run.
      def evaluate(src, ctx = {})
        compile(src).call(ctx)
      end

      def truthy(v); v != false && !v.nil?; end

      def compare(op, a, b)
        case op
        when "==" then a == b
        when "!=" then a != b
        when "<"  then a < b
        when "<=" then a <= b
        when ">"  then a > b
        when ">=" then a >= b
        end
      end

      def roll(dice)
        n, sides = dice.split("d").map(&:to_i)
        n.times.sum { rand(sides) + 1 }
      end

      TOKEN = /\s*(?:(\d+d\d+)|(\d+)|'([^']*)'|(==|!=|<=|>=|[<>()+\-*\/])|([A-Za-z_]\w*))/.freeze

      def tokenize(src)
        toks = []; pos = 0
        while pos < src.length
          m = TOKEN.match(src, pos)
          raise "bad expression near #{src[pos..].inspect}" unless m && m.begin(0) == pos
          pos = m.end(0)
          if    m[1] then toks << [:dice, m[1]]
          elsif m[2] then toks << [:num, m[2].to_i]
          elsif m[3] then toks << [:str, m[3]]
          elsif m[4] then toks << [:op, m[4]]
          elsif m[5] then toks << (%w[and or not flux].include?(m[5]) ? [:kw, m[5]] : [:var, m[5]])
          else raise "bad token"
          end
        end
        toks << [:end, nil]
        toks
      end

      # Recursive descent: or > and > not > comparison > additive > multiplicative > unary > primary.
      # Each binary node is built by a helper taking its operands as ARGUMENTS, so the
      # lambdas close over fresh bindings (not the reused loop variables).
      class Parser
        def initialize(toks); @toks = toks; @i = 0; end
        def peek; @toks[@i]; end
        def take; t = @toks[@i]; @i += 1; t; end
        def accept(type, val = nil); t = peek; (t[0] == type && (val.nil? || t[1] == val)) ? take : nil; end

        def parse
          node = parse_or
          raise "unexpected #{peek.inspect}" unless peek[0] == :end
          node
        end

        def parse_or
          node = parse_and
          node = mk_or(node, parse_and) while accept(:kw, "or")
          node
        end

        def parse_and
          node = parse_not
          node = mk_and(node, parse_not) while accept(:kw, "and")
          node
        end

        def parse_not
          return mk_not(parse_not) if accept(:kw, "not")
          parse_cmp
        end

        def parse_cmp
          node = parse_add
          if (op = %w[== != <= >= < >].map { |o| accept(:op, o) }.compact.first)
            return mk_cmp(op[1], node, parse_add)
          end
          node
        end

        def parse_add
          node = parse_mul
          while (op = accept(:op, "+") || accept(:op, "-"))
            node = mk_arith(op[1], node, parse_mul)
          end
          node
        end

        def parse_mul
          node = parse_unary
          while (op = accept(:op, "*") || accept(:op, "/"))
            node = mk_arith(op[1], node, parse_unary)
          end
          node
        end

        def parse_unary
          return mk_neg(parse_unary) if accept(:op, "-")
          parse_primary
        end

        def parse_primary
          if (t = accept(:num));  v = t[1]; return ->(_c) { v }; end
          if (t = accept(:str));  v = t[1]; return ->(_c) { v }; end
          if (t = accept(:dice)); d = t[1]; return ->(_c) { Expr.roll(d) }; end
          if accept(:kw, "flux");          return ->(_c) { (rand(6) + 1) - (rand(6) + 1) }; end
          if (t = accept(:var));  k = t[1]; return ->(c) { c[k] }; end
          if accept(:op, "(")
            node = parse_or
            accept(:op, ")") or raise "missing ')'"
            return node
          end
          raise "unexpected token #{peek.inspect}"
        end

        # Node builders — operands as arguments => independent closures.
        def mk_or(l, r);  ->(c) { Expr.truthy(l.call(c)) || Expr.truthy(r.call(c)) }; end
        def mk_and(l, r); ->(c) { Expr.truthy(l.call(c)) && Expr.truthy(r.call(c)) }; end
        def mk_not(x);    ->(c) { !Expr.truthy(x.call(c)) }; end
        def mk_cmp(op, l, r); ->(c) { Expr.compare(op, l.call(c), r.call(c)) }; end
        def mk_neg(x);    ->(c) { -x.call(c) }; end
        def mk_arith(op, l, r)
          ->(c) do
            a = l.call(c); b = r.call(c)
            case op when "+" then a + b when "-" then a - b when "*" then a * b else a / b end
          end
        end
      end
    end
  end
end
