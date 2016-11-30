require 'gems'

module Released
  module Goals
    class GemPushed < Released::Goal
      identifier :gem_pushed

      # FIXME: use actual base URL
      BASE_URL = 'http://0.0.0.0:9292'.freeze

      def initialize(config = {})
        @name = config.fetch('name')
        @version = config.fetch('version')

        @rubygems_repo = Gems::Client.new(
          key: config.fetch('authorization'),
          host: config.fetch('rubygems_base_url', BASE_URL),
        )
      end

      def to_s
        "gem pushed (#{@name})"
      end

      def assess
        gems = @rubygems_repo.gems
        if gems =~ /Access Denied/
          raise 'Authorization failed'
        end

        unless gems.any? { |g| g['name'] == @name }
          raise 'List of owned gems does not include request gem'
        end
      end

      def try_achieve
        filename = @name + '-' + @version + '.gem'
        unless File.file?(filename)
          raise "no such gem file: #{filename}"
        end

        File.open(filename, 'r') do |io|
          @rubygems_repo.push(io)
        end
      end

      def achieved?
        @rubygems_repo.gems.any? { |g| g['name'] == @name && g['version'] == @version }
      end

      def failure_reason
        "expected list of gems to contain “#{@name}”, version #{@version}"
      end
    end
  end
end
