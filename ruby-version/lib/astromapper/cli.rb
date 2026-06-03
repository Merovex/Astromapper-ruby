# -*- encoding: utf-8 -*-
require 'thor'
require 'Astromapper/version'
module Astromapper
  class Cli < Thor
    FORMATS = %w[pdf draft proof html epub mobi txt]
    check_unknown_options!
    
    def self.exit_on_failure?
      true
    end
    def initialize(args = [], options = {}, config = {})
      # if (config[:current_task] || config[:current_command]).name == "new" && args.empty?
      #   raise Error, "The e-Book path is required. For details run: Astromapper help new"
      # end
      super
    end

    desc "new", "Create Astromapper Directory"
    map %w(-n new -c) => :create
    def create(path)
      say "Voices of billions cry out in terror at the creation of '#{path}'"
      generator = Generator.new
      generator.destination_root = path.squish.gsub(' ','-')
      generator.invoke_all
    end

    desc "about", "Provide information on a sector"
    map %w{-a} => :about
    def about(volume_id)
      require_project!
      say "Searching database on #{volume_id}"
      source = Astromapper.output_file('sector')
      unless File.exist?(source)
        say "Hey! You need to generate the sector first (try: astromapper build)."
        return
      end

      # Group the sector file into volumes keyed by their 4-digit location.
      volumes = {}
      id = nil
      File.readlines(source).each do |line|
        if /^\d{4}/.match(line)
          id = line[0..3]
          volumes[id] = []
        end
        volumes[id] << line unless id.nil?
      end

      block = volumes[volume_id]
      if block.nil?
        say "No volume #{volume_id} found in #{source}.", :red
        return
      end

      # The header line is tab-delimited; its first field is space-delimited.
      header = block.first.chomp.split("\t")
      loc, uwp, temp, bases, travel = header[0].split(' ')
      trade    = (header[1] || '').strip
      factions = (header[2] || '').strip
      crib     = (header[3] || '').strip
      name     = (header[4] || '').strip
      extn     = (header[5] || '').strip
      native   = (header[6] || '').strip

      say "#{name} (#{loc})", :green
      puts "  UWP .......... #{uwp}"
      puts "  Temperature .. #{temp}"
      puts "  Bases ........ #{bases}"
      puts "  Travel Code .. #{travel}"
      puts "  Trade Codes .. #{trade}"    unless trade.empty?
      puts "  Factions ..... #{factions}" unless factions.empty?
      puts "  Extensions ... #{extn}"     unless extn.empty?
      puts "  Native life .. #{native}"   unless native.empty?
      puts "  Stars/Orbits . #{crib}"
      puts
      say block.join('')
    end

    desc "build", "Generate a map of {sector / domain}"
    map %w{-b --build generate} => :build
    method_option :seed, type: :string, aliases: "-S",
      desc: "Seed (XXXXX-XXXXX or any string) for reproducible generation"
    def build(type='sector')
      require_project!
      configured = options[:seed] || config['seed']
      code, int  = Astromapper::Seed.resolve(configured)
      srand(int)
      say "Seed: #{code}", :yellow
      # If no seed was set (config blank and no --seed), persist the one we just rolled so
      # the map is reproducible. Clear `seed:` in _astromapper.yml to regenerate a new map.
      save_seed(code) if (configured.nil? || configured.to_s.strip.empty?)
      say "Building #{type}: #{config['name'].inspect}"
      Astromapper::Exporter.run(root_dir, options)
    end

    desc "svg", "Convert ASCII output to SVG"
    map %w{-s --svg} => :svg
    method_option :seed, type: :string, aliases: "-S",
      desc: "Seed for reproducible belt jitter (defaults to the project seed)"
    def svg
      require_project!
      # Keep the cosmetic belt jitter reproducible when a seed is configured.
      seed = options[:seed] || config['seed']
      srand(Astromapper::Seed.resolve(seed).last) unless seed.nil? || seed.to_s.strip.empty?
      source = Astromapper.output_file('sector')
      say "Converting #{source} to SVG"
      s = Svg.new(source)
      s.convert
      say "SVG available at #{Astromapper.output_file('svg')}"
    end
    
    desc "version", "Prints the Astromapper's version information"
    map %w(-v --version) => :version
    def version
      say "Astromapper version #{Astromapper::VERSION}"
    end
    
    private
      def config
        # YAML.load_file(config_path).with_indifferent_access
        Astromapper.config
      end
      def root_dir
        @root ||= Pathname.new(Dir.pwd)
      end
      # Abort cleanly (no stack trace) when run outside an Astromapper project.
      def require_project!
        return if File.file?(root_dir.join("_astromapper.yml"))
        raise Thor::Error, "No Astromapper project here (missing _astromapper.yml).\n" \
          "Run `astromapper new <name>` to create one, then `cd` into it and try again."
      end
      # Write the rolled seed back into _astromapper.yml so the map can be reproduced.
      def save_seed(code)
        path    = root_dir.join("_astromapper.yml")
        content = File.read(path)
        if content =~ /^seed:.*$/
          content = content.sub(/^seed:.*$/, "seed: #{code}")
        else
          content = content.rstrip + "\nseed: #{code}\n"
        end
        File.write(path, content)
        say "Saved seed #{code} to _astromapper.yml (clear it to regenerate)", :green
      end
  end
end