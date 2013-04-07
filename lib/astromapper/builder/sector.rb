module Astromapper
  module Builder
    class Sector < Astromapper::Builder::Base
    	def constitute
    		puts "-- Creating Sector #{root_dir}"
    		puts config.inspect
  		end
    end
  end
end