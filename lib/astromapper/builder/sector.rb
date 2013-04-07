module Astromapper
  module Builder
    class Sector < Astromapper::Builder::Base
    	def constitute
    		@volumes = []
				40.times do |r|
					puts "Generating row: #{r+1}"
					32.times do |c|
					# next unless has_system?
					v = Volume.new(c+1,r+1) 
					@volumes << v unless v.empty?
					end
				end
				self
  		end
  		def has_system?
		    case
			    when config['density'] == 'extra_galactic' then (toss(3,0) > 18)
		      when config['density'] == 'rift'      then (toss(2,0) == 12)
		      when config['density'] == 'sparse'    then (toss(1,0) > 5)
		      when config['density'] == 'scattered' then (toss(1,0) > 4)
		      when config['density'] == 'dense'     then (toss(1,0) > 2)
		      when config['density'] == 'cluster'   then (toss(1,0) > 1)
		      when config['density'] == 'core'			then (toss(2,0) > 2)
		      else (toss(1,0) > 3) # Standard
		    end
  		end
  		def to_file
		    # filename = @name.downcase + '.sector'
		    filename = 'output/sector.txt'
		    File.open(filename,'w').write(@volumes.map{|v| v.to_ascii}.join("\n"))
		  end
    end
  end
end