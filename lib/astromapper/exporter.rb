module Astromapper
  class Exporter
    def self.run(root_dir, options)
      exporter = new(root_dir, options)
      exporter.export!
    end

    attr_accessor :root_dir
    attr_accessor :options

    def initialize(root_dir, options)
      @root_dir = root_dir
      @options = options
    end

    def ui
      @ui ||= Thor::Base.shell.new
    end

    def export!
      helper = root_dir.join("config/helper.rb")
      load(helper) if helper.exist?
      exported = [0]

      exported << Builder::Sector.build(root_dir)
      # export_pdf  = [nil, "pdf"].include?(options[:only])
      # export_html = [nil, "html", "mobi", "epub"].include?(options[:only])
      # export_epub = [nil, "mobi", "epub"].include?(options[:only])
      # export_mobi = [nil, "mobi"].include?(options[:only])
      # export_txt  = [nil, "txt"].include?(options[:only])

      # exported = []
      # exported << Parser::PDF.parse(root_dir) if export_pdf && Dependency.xelatex?# && Dependency.prince?
      # exported << Parser::HTML.parse(root_dir) if export_html 
      # epub_done = Parser::Epub.parse(root_dir) if export_epub
      # exported << epub_done
      # exported << Parser::Mobi.parse(root_dir) if export_mobi && epub_done && Dependency.kindlegen?
      # exported << Parser::Txt.parse(root_dir) if export_txt && Dependency.html2text?

      if exported.all?
        color = :green
        message = options[:auto] ? "exported!" : "** e-book has been exported"

        # Notifier.notify(
        #   # :image   => Astromapper::ROOT.join("templates/ebook.png"),
        #   :title   => "Astromapper",
        #   :message => "Your \"#{config[:title]}\" map has been exported!"
        # )
      else
        color = :red
        message = options[:auto] ? "could not be exported!" : "** e-book couldn't be exported"
      end

      ui.say message, color
    end

    def config
      Astromapper.config(root_dir)
    end
  end
end