require 'trollop'
require 'aws-sdk'

module AwsUtils
  class AwsLogs
    def opts
      @opts ||= Trollop.options do
        opt :group,
            'Log group (e.g. /aws/lambda/sf-updater)',
            required: true,
            type: :string,
            short: 'g'
        opt :filter_pattern,
            'See: http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/FilterAndPatternSyntax.html',
            required: true,
            type: :string,
            short: 'f'
        opt :streams_prefix,
            'E.g. 2016/08',
            default: Time.now.strftime('%Y/%m/%d'),
            short: 's'
      end
    end

    def chunk_events(streams_chunk, token = nil)
      response = cloudwatchlogs.filter_log_events(
        log_group_name: opts[:group],
        log_stream_names: streams_chunk,
        filter_pattern: opts[:filter_pattern],
        next_token: token
      )
      collector = response.events
      collector += chunk_events(streams_chunk, response.next_token) if response.next_token
      collector
    end

    def log_events
      # puts "Filtering from #{streams.count} streams in #{streams.count / 50 + 1} chunks"
      streams.each_slice(50).to_a.each_with_object([]) do |streams_chunk, collector|
        collector += chunk_events(streams_chunk)
      end
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
