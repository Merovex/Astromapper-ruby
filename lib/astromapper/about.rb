module Astromapper
  class About
  	def initialize(filename, volume_id)
  		puts "Here > #{filename}"
  		@volumes = {}
  		@volume_id = volume_id.to_s
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
  	def volume
  		@volumes[@volume_id]
  	end
  	def ascii
  		puts "```\n#{volume.join("")}```"
  	end
  	def world
  		# summary = volume
  		volume.each do |b|
  		end
  	end
  end
end