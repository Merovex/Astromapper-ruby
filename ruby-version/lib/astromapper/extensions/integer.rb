class Integer
  def dn(n)
       (1..self).inject(0) { |a, e| a + rand(n) + 1 }
  end
  def d3
    dn(3)
  end
  def d6
    dn(6)
  end
  def d100
    dn(100)
  end
  # Traveller extended hex (T5): 0-9, A-H, J-N, P-Z — omits I and O to avoid
  # confusion with 1 and 0. So 15->F, 16->G, 17->H, 18->J, ...
  EHEX = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZ".freeze
  def hexd
    n = self.whole
    n < EHEX.length ? EHEX[n] : EHEX[-1]
  end
  def whole
    return 0 if self < 0
    return self
  end
  def natural
    return 1 if self < 1
    return self
  end
  def roman
    return 'D' if self ==500
    return %w{Ia Ib II III IV V VI VII VIII IX X}[self]
  end
  def max(n)
    return n if self > n
    return self
  end
  def min(n)
    return n if self < n
    return self
  end
  def tweak
    return self
  end
  def to_string
    return self.tweak
  end
end
