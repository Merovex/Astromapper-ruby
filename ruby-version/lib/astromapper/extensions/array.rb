class Array
  def roll(n=1)
    n.times.map{ self.rotate!; self.first }.inject{|s,x| s + x}
  end
  def distance(other)
    x, y   = self
    x1, y1 = other
    return Math.sqrt((x - x1)**2 + (y - y1)**2).round(0)
  end
  def slope(other)
    answer = (other.first.to_i - self.first.to_i == 0) ? 0.01 : (other.last.to_i - self.last.to_i) / (other.first.to_i - self.first.to_i)
    answer = 0.1 if (self.first.to_i < other.first.to_i and answer == 0)
    return answer.to_f.round(1)
  end
  def overlaps?(other, ary)
    self_m = self.slope(other)
    ary.each do |a|
      m = self.slope(a)
      puts "#{self}:#{a} / #{self_m}:#{m}"
    end

    return false
  end
  def to_hex
    "%02d%02d" % [self[0], self[1]]
  end
  # alias to_s to_hex
  def each_hex
    self.each do |key|
      x = key[0..1].to_i
      y = key[2..3].to_i
      [ (-4..4).to_a, # x + 0
        (-4..3).to_a, # x + 1
        (-3..3).to_a, # x + 2
        (-3..2).to_a, # x + 3
        (-2..2).to_a, # x + 4
      ].each_with_index do |sequence,index|
        [index, index * -1].each do |i|
          x1 = x + i
          sequence.each do |j|
            yield [[x, y], [x1, (y + j)]]
          end
        end
      end
    end
  end
end
