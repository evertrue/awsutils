require 'json'
require 'net/http'
# require 'aws-sdk' # see the comment on `image_details` below

module AwsUtils
  class Ec2LatestImage
    def releases
      @releases ||= begin
        resp = JSON.parse(
          Net::HTTP.get(
            URI('http://cloud-images.ubuntu.com/locator/ec2/releasesTable')
          ).sub(/\],\n\]/, "]\n]")
        )
        parse_releases_array(resp['aaData']).select do |rel|
          rel[:region] == 'us-east-1' &&
          rel[:distro_version] == '14.04 LTS' &&
          rel[:arch] == 'amd64'
        end
      end
    end

    def run
      print_releases
    end

    private

    def print_releases
      # Print a header
      printf("%-13s %-10s %-9s %-20s\n", 'ID', 'Version', 'Release', 'Type')

      puts('-' * 53)

      # Print the releases
      releases.each do |rel|
        printf(
          "%-13s %-10s %-9s %-20s\n",
          rel[:ami],
          rel[:distro_version],
          rel[:release],
          rel[:type]
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
  end
end
