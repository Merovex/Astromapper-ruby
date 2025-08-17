module Astromapper
  module Builder
    class Sector < Astromapper::Builder::Base
    	def constitute
    		@volumes = []
				40.times do |r|
					32.times do |c|
					next unless has_system?
					v = Volume.new(c+1,r+1) 
					@volumes << v unless v.empty?
					end
				end
				self
  		end
  		def has_system?
		    case
			    when config['density'] == 'extra_galactic' 	then (1.d100 <= 1)
		      when config['density'] == 'rift'      			then (1.d100 <= 3)
		      when config['density'] == 'sparse'    			then (1.d100 <= 17)
		      when config['density'] == 'scattered' 			then (1.d100 <= 33)
		      when config['density'] == 'dense'     			then (1.d100 <= 66)
		      when config['density'] == 'cluster'   			then (1.d100 <= 83)
		      when config['density'] == 'core'						then (1.d100 <= 91)
		      else (d100 <= 50) # Standard
		    end
  		end
  		def to_file
  			file = Astromapper.output_file('sector')
		    File.open(file,'w').write(@volumes.map{|v| v.to_ascii}.join("\n"))
		  end
    end
  end
end