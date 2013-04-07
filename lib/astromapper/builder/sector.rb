module Astromapper
  module Builder
    class Sector < Base
    	def self.build(root_dir)
    		puts "-- Creating Sector #{root_dir}"
    		# locals = config.merge({})
    		# puts config().inspect
    		# puts Base.config.inspect
    		# puts showme
    		puts config.inspect
    	end
    	def config
        Astromapper.config(root_dir)
      end
    end
  end
end