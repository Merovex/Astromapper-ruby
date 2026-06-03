require 'securerandom'

module Astromapper
  # Reproducible-seed handling.
  #
  # A seed is a human-readable Crawford code in the form XXXXX-XXXXX, using a
  # 32-character set that omits easily-confused glyphs (no I, O, 0, 1). Any
  # arbitrary string is deterministically folded into a Crawford code, and the
  # code is then folded into a 64-bit integer with FNV-1a. The same derivation
  # is used by the Go and Rust ports, so a given code maps to the same integer
  # seed in every implementation (the per-language RNG streams still differ).
  module Seed
    CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".freeze # 32 glyphs
    FNV_OFFSET = 0xcbf29ce484222325
    FNV_PRIME  = 0x100000001b3
    MASK64     = 0xFFFFFFFFFFFFFFFF

    module_function

    # 64-bit FNV-1a hash of a string (matches Go's hash/fnv New64a).
    def fnv1a64(str)
      hash = FNV_OFFSET
      str.to_s.each_byte do |b|
        hash ^= b
        hash = (hash * FNV_PRIME) & MASK64
      end
      hash
    end

    # Is the value already a canonical Crawford code (XXXXX-XXXXX)?
    def crawford?(value)
      s = value.to_s.upcase
      return false unless s.length == 11 && s[5] == '-'
      (s[0, 5] + s[6, 5]).each_char.all? { |c| CHARSET.include?(c) }
    end

    # Fold any string into a Crawford code via FNV-1a + 6-bit slicing.
    def crawford_from(input)
      hash = fnv1a64(input)
      chars = (0...10).map { |i| CHARSET[(hash >> (i * 6)) % CHARSET.length] }
      chars[0, 5].join + "-" + chars[5, 5].join
    end

    # A fresh random Crawford code (cryptographically random glyphs).
    def random_code
      chars = (0...10).map { CHARSET[SecureRandom.random_number(CHARSET.length)] }
      chars[0, 5].join + "-" + chars[5, 5].join
    end

    # Resolve user input to a [crawford_code, integer_seed] pair.
    #   nil/blank        -> a new random code
    #   a Crawford code  -> used as-is
    #   any other string -> folded into a Crawford code
    def resolve(input)
      code =
        if input.nil? || input.to_s.strip.empty?
          random_code
        elsif crawford?(input)
          input.to_s.upcase
        else
          crawford_from(input)
        end
      [code, fnv1a64(code)]
    end
  end
end
