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
				prune_isolated! unless [false, 'false'].include?(config['prune_isolated'])
				self
  		end
  		# Remove systems with no neighbour within jump-4 — lone stars that no route
  		# can reach. Isolated systems form an independent set (a system with a
  		# neighbour in range is, by symmetry, a neighbour to it), so one pass
  		# cannot create new isolates. On by default; disable with `prune_isolated: false`.
  		def prune_isolated!(threshold = 4)
  			coords = @volumes.map { |v| [v.column, v.row] }
  			@volumes = @volumes.reject do |v|
  				here = [v.column, v.row]
  				coords.none? { |o| o != here && Astromapper::Islands.jump(here, o) <= threshold }
  			end
  		end
  		def has_system?
		    case
			    when config['density'] == 'extra_galactic' 	then (1.d100 <= 1)
		      when config['density'] == 'rift'      			then (1.d100 <= 3)
		      when config['density'] == 'sparse'    			then (1.d100 <= 17)
		      when config['density'] == 'dunbar'    			then (1.d100 <= 23) # ~150 systems (Dunbar's Number)
		      when config['density'] == 'scattered' 			then (1.d100 <= 33)
		      when config['density'] == 'dense'     			then (1.d100 <= 66)
		      when config['density'] == 'cluster'   			then (1.d100 <= 83)
		      when config['density'] == 'core'						then (1.d100 <= 91)
		      else (1.d100 <= 50) # Standard
		    end
  		end
  		def to_file
  			file = Astromapper.output_file('sector')
		    File.open(file,'w').write(key + @volumes.map{|v| v.to_ascii}.join("\n"))
		  end
		  # T5 Second Survey (TravellerMap) tab-delimited export — the standard
		  # interchange format. Columns: Sector SS Hex Name UWP Bases Remarks Zone
		  # PBG Allegiance Stars {Ix} (Ex) [Cx] Nobility W RU.
		  T5_COLUMNS = %w[Sector SS Hex Name UWP Bases Remarks Zone PBG Allegiance Stars {Ix} (Ex) [Cx] Nobility W RU].freeze
		  def to_tab
		    allegiance = config['allegiance'] || 'Na'
		    rows = @volumes.sort_by { |v| [v.row, v.column] }.map { |v| v.to_tab(config['name'], allegiance) }
		    ([T5_COLUMNS.join("\t")] + rows).join("\n") + "\n"
		  end
		  def to_tab_file
		    File.open(Astromapper.output_file('tab'), 'w').write(to_tab)
		  end
		  # Legend prepended to the sector file. Lines start with '#', so the SVG/about
		  # parsers (which match /^\d{4}/) skip them.
		  def key
		    <<~KEY
		      # Astromapper Sector: #{config['name']}
		      # Allegiance: #{config['allegiance'] || 'Im'}
		      #
		      # System line fields (left to right):
		      #   Loc  UWP  Tmp  Bases  TZ  Trade  Factions  Stars  Orbits  Name  Ix  Ex  Cx
		      #
		      #   Loc       Hex location (column+row, e.g. 0601)
		      #   UWP       Universal World Profile: Starport Size Atmo Hydro Pop Gov Law-Tech (eHex)
		      #   Tmp       Climate (by Habitable Zone): T Temperate, H Hot, C Cold, Tz Twilight, Lk Locked
		      #   Bases     Naval Scout GasGiant Depot WayStation   (. = none)
		      #   TZ        Travel Zone: AZ Amber, RZ Red, .. none
		      #   Trade     Trade classification codes
		      #   Factions  Faction government types: O F M N S P
		      #   Stars     Star classifications, primary/companions (e.g. M6V, G2V/DB)
		      #   Orbits    W World  G GasGiant  B Belt  R Rock  H Hostile  S Companion  . empty
		      #   Name      Mainworld name
		      #   Ix {+-n}  Importance Extension
		      #   Ex (RLI+-E)  Economic: Resources Labor Infrastructure Efficiency
		      #   Cx [HASS] Cultural: Homogeneity Acceptance Strangeness Symbols
		      #   RU:n      Resource Units (R x L x I x E) - total economic output
		      #   Native    Population: Settled, Colony (human); or Native, Exotic (sophonts: varied)
		      #
		      # Orbit lines ( -- ): orbit no., * = biozone, type, UWP, distance (AU).
		      # Moon lines  (  / ): orbital radii, moon UWP.
		      #
		    KEY
		  end
    end
  end
end