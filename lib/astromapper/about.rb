module Astromapper
  class About
  	def initialize(filename)
  		puts "Here > #{filename}"
  		@volumes = {}
  		volume = []
  		volume_id = ""
  		File.open(filename,'r').readlines.each do |line|
  			if /^\d{4}/.match(line)
  				@volumes[volume_id.to_s] = volume unless volume.nil? or volume_id == ""
  				volume = []
  				volume_id = line[0..3]
  			end
			volume << line unless volume.nil?
  		end
  	end
  	def tell(volume_id)
  		puts @volumes[volume_id.to_s].join("")
  	end
  end
end