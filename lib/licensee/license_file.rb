class Licensee
  class LicenseFile

    FILENAMES = %w[
      LICENSE
      LICENSE.txt
      LICENSE.md
      UNLICENSE
      COPYING
    ]

    attr_reader :path
    attr_accessor :contents

    def initialize(path=nil)
      @path = File.expand_path(path) unless path.nil?
    end

    def contents
      @contents ||= File.open(path).read
    end
    alias_method :to_s, :contents
    alias_method :content, :contents

    def self.find(base_path)
      raise "Invalid directory" unless directory_exists? base_path
      file = self::FILENAMES.find { |file| file_exists?(file, base_path) }
      new(File.expand_path(file, base_path)) if file
    end

    def self.directory_exists?(base_path)
      File.directory?(base_path)
    end

    def self.file_exists?(file, base_path)
      File.exists? File.expand_path(file, base_path)
    end

    def length
      @length ||= content_normalized.length
    end

    def length_delta(license)
      (length - license.length).abs
    end

    def potential_licenses
      @potential_licenses ||= begin
        max_delta = length * (1 - Licensee::CONFIDENCE_THRESHOLD)
        Licensee::Licenses.list.clone.select do
          |license| length_delta(license) <= max_delta
        end
      end
    end

    def licenses_sorted
      @licenses_sorted ||= potential_licenses.sort_by { |l| length_delta(l) }
    end

    def matches
      @matches ||= begin
        results = Parallel.map_with_index(licenses_sorted) { |l,index| [distance(l), index] }
        results.each { |distance,index| licenses_sorted[index].match = distance }
        licenses_sorted.sort_by { |l| l.match }.reverse
      end
    end

    def match
      @match ||= licenses_sorted.find do |license|
        license.match = distance(license)
        license.match >= Licensee::CONFIDENCE_THRESHOLD
      end
    end

    def distance(license)
      Licensee.matcher.getDistance content_normalized, license.body
    end

    def diff(options=nil)
      Diffy::Diff.new(match.raw_body, content).to_s(options)
    end

    private

    def content_normalized
      contents.downcase.gsub(/\s+/, "")
    end
  end
end
