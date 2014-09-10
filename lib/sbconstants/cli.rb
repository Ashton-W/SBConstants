require 'set'

module SBConstants
  class CLI
    attr_accessor :options, :constants, :sections

    def self.run argv
      new(Options.parse(argv)).run
    end

    def initialize options
      self.options   = options
      self.constants = Hash.new { |h,k| h[k] = Set.new }
    end

    def run
      parse_storyboards
      write
    end

    def sections
      @sections ||= begin
        sections_map = Hash.new { |h,k| h[k] = Set.new }
        constants.each do |constant, locations|
          sections_map[locations] << constant
        end
        @sections = []
        sections_map.each do |k,v|
          @sections << Section.new(k.to_a, v.to_a.sort)
        end
        @sections = @sections.sort_by { |section| section.locations.map(&:key_path).join(',') }
      end
    end

    private

    def parse_storyboards
      Dir["#{options.source_dir}/**/*.storyboard"].each do |storyboard|
        File.readlines(storyboard).each_with_index do |line, index|
          options.queries.each do |query|
            next unless value = line[query.regex, 1]
            next if value.strip.empty?
            next unless value.start_with?(options.prefix) if options.prefix

            constants[value] << Location.new(query.node, query.attribute, line.strip, File.basename(storyboard, '.storyboard'), index + 1)
          end
        end
      end
    end

    def write
      int_out, imp_out, swift_out = $stdout, $stdout, $stdout
      dry_run = options.dry_run

      if options.use_swift
          swift_out = File.open("#{options.output_path}.swift", 'w') unless dry_run
          SwiftConstantWriter.new(self, swift_out).write
          swift_out.close
      else

        int_out = File.open("#{options.output_path}.h", 'w') unless dry_run
        imp_out = File.open("#{options.output_path}.m", 'w') unless dry_run

        ObjcConstantWriter.new(self, int_out, imp_out).write

        int_out.close unless dry_run
        imp_out.close unless dry_run
      end
    end
  end
end
