module IOStreams
  class Streams
    attr_accessor :file_name
    attr_reader :streams, :options

    def initialize(file_name = nil)
      @file_name = file_name
      @streams   = nil
      @options   = nil
    end

    # Supply an option that is only applied once the file name extensions have been parsed.
    # Note:
    # - Cannot set both `stream` and `option`
    def option(stream, **options)
      stream = stream.to_sym unless stream.is_a?(Symbol)
      raise(ArgumentError, "Invalid stream: #{stream.inspect}") unless IOStreams.extensions.include?(stream)
      raise(ArgumentError, "Cannot call both #option and #stream on the same streams instance}") if @streams
      raise(ArgumentError, "Cannot call #option unless the `file_name` was already set}") unless file_name

      @options ||= {}
      if opts = @options[stream]
        opts.merge!(options)
      else
        @options[stream] = options.dup
      end
      self
    end

    def stream(stream, **options)
      stream = stream.to_sym unless stream.is_a?(Symbol)
      raise(ArgumentError, "Cannot call both #option and #stream on the same streams instance}") if @options

      # To prevent any streams from being applied supply a stream named `:none`
      if stream == :none
        @streams = {}
        return self
      end
      raise(ArgumentError, "Invalid stream: #{stream.inspect}") unless IOStreams.extensions.include?(stream)

      @streams ||= {}
      if opts = @streams[stream]
        opts.merge!(options)
      else
        @streams[stream] = options.dup
      end
      self
    end

    def option_or_stream(stream, **options)
      if streams
        stream(stream, **options)
      elsif file_name
        option(stream, **options)
      else
        stream(stream, **options)
      end
    end

    # Return the options set for either a stream or option.
    def setting(stream)
      return streams[stream] if streams
      options[stream] if options
    end

    def reader(io_stream, &block)
      execute(:reader, pipeline, io_stream, &block)
    end

    def writer(io_stream, &block)
      execute(:writer, pipeline, io_stream, &block)
    end

    # Returns [Hash<Symbol:Hash>] the pipeline of streams
    # with their options that will be applied when the reader or writer is invoked.
    def pipeline
      return streams.dup.freeze if streams
      return {}.freeze unless file_name

      built_streams          = {}
      # Encode stream is always first
      built_streams[:encode] = options[:encode] if options&.key?(:encode)

      opts = options || {}
      parse_extensions.each { |stream| built_streams[stream] = opts[stream] || {} }
      built_streams.freeze
    end

    private

    def class_for_stream(type, stream)
      ext = IOStreams.extensions[stream.nil? ? nil : stream.to_sym] || raise(ArgumentError, "Unknown Stream type: #{stream.inspect}")
      ext.send("#{type}_class") || raise(ArgumentError, "No #{type} registered for Stream type: #{stream.inspect}")
    end

    # Returns the streams for the supplied file_name
    def parse_extensions
      parts      = ::File.basename(file_name).split('.')
      extensions = []
      while extension = parts.pop
        sym = extension.downcase.to_sym
        break unless IOStreams.extensions[sym]

        extensions.unshift(sym)
      end
      extensions
    end

    # Executes the streams that need to be executed.
    def execute(type, pipeline, io_stream, &block)
      raise(ArgumentError, 'IOStreams call is missing mandatory block') if block.nil?

      if pipeline.empty?
        block.call(io_stream)
      elsif pipeline.size == 1
        stream, opts = pipeline.first
        class_for_stream(type, stream).stream(io_stream, opts, &block)
      else
        # Daisy chain multiple streams together
        last = pipeline.keys.inject(block) { |inner, stream| ->(io) { class_for_stream(type, stream).stream(io, pipeline[stream], &inner) } }
        last.call(io_stream)
      end
    end
  end
end
