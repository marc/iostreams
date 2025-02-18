module IOStreams
  module Utils
    # Lazy load dependent gem so that it remains a soft dependency.
    def self.load_dependency(gem_name, stream_type, require_name = gem_name)
      require require_name
    rescue LoadError => e
      raise(LoadError, "Please install the gem '#{gem_name}' to support #{stream_type}. #{e.message}")
    end

    # Helper method: Returns [true|false] if a value is blank?
    def self.blank?(value)
      if value.nil?
        true
      elsif value.is_a?(String)
        value !~ /\S/
      else
        value.respond_to?(:empty?) ? value.empty? : !value
      end
    end

    # Yields the path to a temporary file_name.
    #
    # File is deleted upon completion if present.
    def self.temp_file_name(basename, extension = '')
      result = nil
      ::Dir::Tmpname.create([basename, extension]) do |tmpname|
        begin
          result = yield(tmpname)
        ensure
          ::File.unlink(tmpname) if ::File.exist?(tmpname)
        end
      end
      result
    end
  end
end
