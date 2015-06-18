module RocketJob
  module Streams
    class ZipReader
      # Read from a zip file or stream, decompressing the contents as it is read
      # The input stream from the first file found in the zip file is passed
      # to the supplied block
      #
      # Example:
      #   RocketJob::Reader::Zip.read('abc.zip') do |io_stream, source|
      #     # Display header info
      #     puts source.inspect
      #
      #     # Read 256 bytes at a time
      #     while data = io_stream.read(256)
      #       puts data
      #     end
      #   end
      #
      # Example:
      #   File.open('myfile.zip') do |io|
      #     RocketJob::Reader::Zip.input_stream(io) do |io_stream, source|
      #       # Display header info
      #       puts source.inspect
      #
      #       # Read 256 bytes at a time
      #       while data = io_stream.read(256)
      #         puts data
      #       end
      #     end
      #   end
      #
      # Note: The stream currently only supports #read
      def self.open(file_name_or_io, options={}, &block)
        options       = options.dup
        buffer_size   = options.delete(:buffer_size) || 65536
        raise(ArgumentError, "Unknown RocketJob::Streams::ZipReader option: #{options.inspect}") if options.size > 0

        # File name supplied
        return read_file(file_name_or_io, &block) unless file_name_or_io.respond_to?(:read)

        # Stream supplied
        begin
          # Since ZIP cannot be streamed, download unzipped data to a local file before streaming
          temp_file = Tempfile.new('rocket_job')
          file_name = temp_file.to_path
          # Stream zip stream into temp file
          File.open(file_name, 'wb') do |file|
            while chunk = file_name_or_io.read(buffer_size)
              break if chunk.size == 0
              file.write(chunk)
            end
          end
          read_file(file_name, &block)
        ensure
          temp_file.delete if temp_file
        end
      end

      if defined?(JRuby)
        # Java has built-in support for Zip files
        def self.read_file(file_name, &block)
          fin = Java::JavaIo::FileInputStream.new(file_name)
          zin = Java::JavaUtilZip::ZipInputStream.new(fin)
          zin.get_next_entry
          block.call(zin.to_io)
        ensure
          zin.close if zin
          fin.close if fin
        end

      else
        # MRI needs Ruby Zip, since it only has native support for GZip
        begin
          require 'zip'
        rescue LoadError => exc
          puts "Please install gem rubyzip so that RocketJob can read Zip files in Ruby MRI"
          raise(exc)
        end

        # Read from a zip file or stream, decompressing the contents as it is read
        # The input stream from the first file found in the zip file is passed
        # to the supplied block
        def self.read_file(file_name, &block)
          begin
            zin = ::Zip::InputStream.new(file_name)
            zin.get_next_entry
            block.call(zin)
          ensure
            zin.close if zin
          end
        end

      end
    end
  end
end