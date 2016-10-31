require 'trollop'
require 'aws-sdk'
require 'time'

class LogGroupNotFoundError < StandardError; end
class MultipleGroupsError < StandardError; end
class TooManyEventsError < StandardError; end
class TooManyStreamsError < StandardError; end
class NoStreamsError < StandardError; end

module AwsUtils
  class AwsLogs
    LOG_LEVELS = %w(TRACE DEBUG INFO NOTICE WARNING ERROR FATAL).freeze
    MAX_EVENTS = 100000.freeze
    MAX_STREAMS = 100.freeze

    def run
      print_events
    rescue TooManyEventsError
      puts "Too many log events to process (MAX: #{MAX_EVENTS}). " \
           'Please try filtering the output with -f'
      exit 3
    rescue TooManyStreamsError
      puts "Too many streams to process (MAX: #{MAX_STREAMS}). " \
           'Please try filtering the output with -s'
      exit 3
    rescue LogGroupNotFoundError
      puts "No log groups found starting with #{opts[:group]}"
      exit 1
    rescue NoStreamsError
      puts 'Streams filter did not return any streams'
      exit 1
    rescue MultipleGroupsError => e
      puts e.message
      exit 2
    end

    private

    def opts
      @opts ||= Trollop.options do
        opt :age,
            'Max age in seconds',
            short: 'a',
            type: Integer
        opt :group,
            'Log group (e.g. /aws/lambda/sf-updater)',
            required: true,
            type: String,
            short: 'g'
        opt :filter_pattern,
            'See: http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/FilterAndPatternSyntax.html',
            type: String,
            short: 'f'
        opt :streams_prefix,
            'E.g. 2016/08',
            type: String,
            short: 's'
        opt :timestamp,
            'Include the timestamp from the event metadata in the output',
            short: 't',
            default: false
        opt :show_request_id,
            'Show the request ID in every log message',
            short: 'r',
            default: false
        opt :request_id,
            'Print only messages with a specific request ID',
            short: 'R',
            type: :string
        opt :log_level,
            'Lowest log level to show',
            default: 'INFO',
            short: 'l'
        opt :show_stream_name,
            'Include the name of the log stream on the output line',
            default: false
      end
    end

    def log_group_name
      @log_group ||= begin
        r = cloudwatchlogs.describe_log_groups log_group_name_prefix: opts[:group]
        return r.log_groups.first.log_group_name if r.log_groups.count == 1
        raise LogGroupNotFoundError if r.log_groups.empty?
        err_msg = "Group filter #{opts[:group]} found multiple groups:\n\n"
        err_msg += r.log_groups.map(&:log_group_name).join("\n")
        err_msg += "\nMore than 50 log groups returned. Only showed the first 50." if r.next_token
        raise MultipleGroupsError, err_msg
      end
    end

    def chunk_events(streams_chunk, token = nil)
      parameters = {
        log_group_name: log_group_name,
        log_stream_names: streams_chunk,
        start_time: max_age_ts,
        next_token: token
      }
      parameters[:filter_pattern] = opts[:filter_pattern] if opts[:filter_pattern]
      response = cloudwatchlogs.filter_log_events parameters
      collector = response.events
      collector += chunk_events(streams_chunk, response.next_token) if response.next_token
      raise TooManyEventsError if collector.count > MAX_EVENTS
      collector
    end

    def log_events
      # puts "Filtering from #{streams.count} streams in #{streams.count / 50 + 1} chunks"
      collector = []
      streams.each_slice(50) { |streams_chunk| collector += chunk_events(streams_chunk) }

      puts 'No events found' if collector.empty?

      collector.sort_by(&:timestamp)
    end

    def filtered_log_events
      return log_events unless opts[:request_id]
      log_events.select { |event| event.message =~ /\b#{opts[:request_id]}\b/ }
    end

    def print_events
      filtered_log_events.each do |ev|
        if ev.message !~ /^\[(INFO|DEBUG|WARNING|ERROR|NOTICE)\]/ # Check if the message is in the standard format
          print "#{ev.log_stream_name}: " if opts[:show_stream_name]
          print Time.at(ev.timestamp / 1e3).iso8601(3) + ' ' if opts[:timestamp]
          print ev.message
          print "\n" if ev.message[-1] != "\n"
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
      parameters = {
        log_group_name: log_group_name,
        next_token: token
      }
      parameters[:log_stream_name_prefix] = opts[:streams_prefix] if opts[:streams_prefix]
      response = cloudwatchlogs.describe_log_streams parameters
      collector =
        response
        .log_streams
        .select { |s| s.last_event_timestamp && s.last_event_timestamp > max_age_ts }
        .map(&:log_stream_name)
      fail NoStreamsError if token.nil? && collector.count == 0
      collector += streams(response.next_token) if response.next_token
      fail TooManyStreamsError if collector.count > MAX_STREAMS
      collector
    end

    def max_age_ts
      return 0 unless opts[:age]
      (Time.at(Time.now - opts[:age]).to_f * 1_000).to_i
    end

    def cloudwatchlogs
      @cloudwatchlogs ||= Aws::CloudWatchLogs::Client.new
    end
  end
end
