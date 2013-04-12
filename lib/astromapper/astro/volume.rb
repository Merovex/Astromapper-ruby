module Astromapper
  module Astro
  	class Volume
  		attr_accessor :ascii, :summary
  		def initialize(ascii)
  			@ascii = ascii.join("")
  			@summary = ascii[0]
  			bits = @summary.split("\t")
  			raise bits.inspect
  		end
  	end
  end
end