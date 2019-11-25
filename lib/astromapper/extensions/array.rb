class Array
  def roll(n=1)
    n.times.map{ self.rotate!; self.first }.inject{|s,x| s + x}
  end
  def each_hex
    self.each do |key|
      x = key[0..1].to_i
      y = key[2..3].to_i
      [ (-4..4).to_a, # x + 0
        (-3..4).to_a, # x + 1
        (-3..3).to_a, # x + 2
        (-2..3).to_a, # x + 3
        (-2..2).to_a, # x + 4
      ].each_with_index do |sequence,index|
        [index, index * -1].each do |i|
          x1 = x + i
          sequence.each do |j|
            yield [x, y, x1, (y + j)]
          end
        end
      end
    end
  end
end
