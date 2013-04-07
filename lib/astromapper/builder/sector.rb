module Astromapper
  module Builder
    class Sector < Base
    	def self.build(root_dir)
    		puts "-- Creating Sector #{root_dir}"
    		puts config.inspect
  		end
    end
  end
end