require 'trollop'
require 'aws-sdk'
require 'time'

module AwsUtils
  class AwsLogs
    LOG_LEVELS = %w(TRACE DEBUG INFO NOTICE WARNING ERROR FATAL).freeze

    def opts
      @opts ||= Trollop.options do
        opt :group,
            'Log group (e.g. /aws/lambda/sf-updater)',
            required: true,
            type: :string,
            short: 'g'
        opt :filter_pattern,
            'See: http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/FilterAndPatternSyntax.html',
            short: 'f'
        opt :streams_prefix,
            'E.g. 2016/08',
            default: Time.now.strftime('%Y/%m/%d'),
            short: 's'
        opt :timestamp,
            'Include the timestamp from the event metadata in the output',
            short: 't',
            default: false
        opt :show_request_id,
            'Show the request ID in every log message',
            short: 'r',
            default: false
        opt :log_level,
            'Lowest log level to show',
            default: 'INFO',
            short: 'l'
        opt :show_stream_name,
            'Include the name of the log stream on the output line',
            default: false
      end
    end

    def chunk_events(streams_chunk, token = nil)
      parameters = {
        log_group_name: opts[:group],
        log_stream_names: streams_chunk,
        next_token: token
      }
      parameters[:filter_pattern] = opts[:filter_pattern] if opts[:filter_pattern]
      response = cloudwatchlogs.filter_log_events parameters
      collector = response.events
      collector += chunk_events(streams_chunk, response.next_token) if response.next_token
      collector
    end

    def log_events
      # puts "Filtering from #{streams.count} streams in #{streams.count / 50 + 1} chunks"
      collector = []
      streams.each_slice(50) { |streams_chunk| collector += chunk_events(streams_chunk) }

      puts 'No events found' if collector.empty?

      collector.sort_by(&:timestamp)
    end

    def print_events
      log_events.each do |ev|
        if ev.message !~ /^\[(INFO|DEBUG|WARNING|ERROR|NOTICE)\]/ # Check if the message is in the standard format
          print "#{ev.log_stream_name}: " if opts[:show_stream_name]
          print Time.at(ev.timestamp / 1e3).iso8601(3) + ' ' if opts[:timestamp]
          print ev.message
          next
        end

        msg_parts = ev.message.split("\t")
        level      = msg_parts[0].scan(/\[(\w*)\]/)[-1][0]
        timestamp  = msg_parts[1]
        request_id = msg_parts[2]
        message    = msg_parts[3..-1].join("\t")

        next unless show_logentry? level

        print "#{ev.log_stream_name}: " if opts[:show_stream_name]
        print Time.at(ev.timestamp / 1e3).iso8601(3) if opts[:timestamp]
        printf('%-24s %-10s', timestamp, "[#{level}]")
        printf('%-37s', request_id) if opts[:show_request_id]
        print(message)
      end
    end

    def show_logentry?(level)
      return true unless LOG_LEVELS.include? level
      LOG_LEVELS.index(level.upcase) >= LOG_LEVELS.index(opts[:log_level].upcase)
    end

    def streams(token = nil)
      response = cloudwatchlogs.describe_log_streams(
        log_group_name: opts[:group],
        log_stream_name_prefix: opts[:streams_prefix],
        next_token: token
      )
      collector = response.log_streams.map(&:log_stream_name)
      collector += streams(response.next_token) if response.next_token
      collector
    end

    def cloudwatchlogs
      @cloudwatchlogs ||= Aws::CloudWatchLogs::Client.new
    end
  end
end
