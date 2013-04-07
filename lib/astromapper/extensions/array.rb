class Array
  def roll(n=1)
    n.times.map{ self.rotate!; self.first }.inject{|s,x| s + x}
  end
end