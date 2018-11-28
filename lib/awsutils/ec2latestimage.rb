require 'json'
require 'net/http'
require 'optimist'
# require 'aws-sdk-ec2' # see the comment on `image_details` below

module AwsUtils
  class Ec2LatestImage
    def releases
      @releases ||= begin
        parsed_releases =
          if opts[:ownedbyme]
            fail 'AWS_OWNER_ID not defined' unless ENV['AWS_OWNER_ID']

            require 'aws-sdk-ec2'

            ubuntu_images =
              connection.describe_images(owners: [ENV['AWS_OWNER_ID']]).images.select do |image|
                image.name =~ %r{^ubuntu\/}
              end

            ubuntu_images.map do |image|
              {
                ami: image.image_id,
                distro_version: image.name.split('/')[3].split('-')[2],
                release: image.name.split('/')[3].split('-')[5..-1].join('-'),
                type: image.name.split('/')[2] + ':' + image.root_device_type,
                arch: image.architecture,
                region: opts[:region] # overriding this because images API doesn't list a region
              }
            end
          else
            resp = JSON.parse(
              Net::HTTP.get(
                URI("http://cloud-images.ubuntu.com/locator/ec2/releasesTable?_=#{(Time.now.to_f*1000).to_i}")
              ).sub(/\],\n\]/, "]\n]")
            )
            parse_releases_array(resp['aaData'])
          end

        parsed_releases.select do |rel|
          rel[:region] == opts[:region] &&
          rel[:distro_version] == "#{opts[:release]}" &&
          %w(amd64 x86_64).include?(rel[:arch])
        end
      end
    end

    def run
      print_releases
    end

    private

    def print_releases
      # Print a header
      printf("%-13s %-10s %-20s %-9s\n", 'ID', 'Version', 'Type', 'Release')

      puts('-' * 72)

      # Print the releases
      releases.each do |rel|
        printf(
          "%-13s %-10s %-20s %-9s\n",
          rel[:ami],
          rel[:distro_version],
          rel[:type],
          rel[:release]
        )
      end
    end

    # def image_details
    #   This functionalty allows us to get more image details from the AWS API but
    #   it's not necessary for the library to work and right now we're not using it
    #   because it slows down loading time.
    #
    #   @our_images ||= begin
    #     our_ami_ids = releases.map { |rel| rel[:ami] }
    #     images_details = connection.describe_images(image_ids: our_ami_ids).images

    #     images_details.each_with_object({}) { |ami, m| m[ami.image_id] = ami }
    #   end
    # end

    # rubocop:disable Metrics/MethodLength
    def parse_releases_array(releases)
      releases.map do |rel|
        {
          region:         rel[0],
          distro_name:    rel[1],
          distro_version: rel[2],
          arch:           rel[3],
          type:           rel[4],
          release:        rel[5],
          ami:            parse_ami_link(rel[6]),
          aki:            rel[7]
        }
      end
    end
    # rubocop:enable Metrics/MethodLength

    def parse_ami_link(link)
      link.match(/launchAmi=(ami-\w{8})/)[1]
    end

    def connection
      @connection ||= Aws::EC2::Client.new
    end

    def opts
      @opts ||= Optimist.options do
        opt :release, 'Ubuntu release', short: 'r', default: '16.04 LTS'
        opt :ownedbyme, 'Images owned by $AWS_OWNER_ID', short: 'o', default: false
        opt :region, 'Image region', short: 'R', default: 'us-east-1'
      end
    end
  end
end
