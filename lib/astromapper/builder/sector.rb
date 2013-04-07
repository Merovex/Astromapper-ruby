module Astromapper
  module Builder
    class Sector < Astromapper::Builder::Base
    	def constitute
    		@volumes = []
    		puts "-- Creating Sector #{root_dir}"
				40.times do |r|
					32.times do |c|
					# next unless has_system?
					v = Volume.new(c+1,r+1) 
					@volumes << v unless v.empty?
					end
				end
  		end
  		def has_system?
		    case
		      when config['density'] == 'rift'      then (toss(2,0) == 12)
		      when config['density'] == 'sparse'    then (toss(1,0) > 5)
		      when config['density'] == 'scattered' then (toss(1,0) > 4)
		      when config['density'] == 'dense'     then (toss(1,0) > 2)
		      else (toss(1,0) > 3)
		    end
  		end
    end
  end
end