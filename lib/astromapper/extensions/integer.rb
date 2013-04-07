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
  def hexd
    return 'F' if self > 15
    self.whole.to_s(16).upcase
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