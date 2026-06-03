class String
  def to_permalink
    str = self.dup.unicode_normalize(:nfkd).gsub(/[^\x00-\x7F]/, '')
    str.gsub!(/[^-\w\d]+/xim, "-")
    str.gsub!(/-+/xm, "-")
    str.gsub!(/^-?(.*?)-?$/, '\1')
    str.downcase!
    str
  end
  def to_coords
  end
end
