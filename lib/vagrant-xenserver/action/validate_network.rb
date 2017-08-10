require "etc"
require "log4r"
require "xmlrpc/client"
require "net/ping/external"

module VagrantPlugins
  module XenServer
    module Action
      class ValidateNetwork
        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new("vagrant::xenserver::actions::validate_network")
        end

        def ping(host)
          check = Net::Ping::External.new(host)
          check.timeout = 1
          check.ping?
        end

        # Choose next IP if available
        def next_hashed_ip(host, prefix, timeout=10)
          begin
            h = hash_last_octet(host)
            Timeout::timeout(timeout) do
              (((h-1)..253).to_a + (3..h).to_a).each do |i|
                ip = "#{prefix}.#{i}"
                taken = ping(ip)
                return ip if not taken
              end
              sleep timeout + 1
            end
          rescue Timeout::Error, StandardError
            raise Errors::CannotAllocateAddress, subnet: prefix
          end
        end

        def hash_last_octet(n)
          # compute hostname (string) to a number between 3..253
          # include username too, so ip conflict is less likely happen
          def _split(i)
            i.split("").map do |x|
              c = x.to_i
              if c == 0
                # if not number, convert "a"->1, "b"->2, dst
                c = (x.upcase.ord - 64).abs
              end
              c
            end
          end
          # sum the array and return a number which is not 1,2 or 253
          # as it is usually a gateway address / router
          ((_split "#{Etc.getlogin}-#{n}").inject(:+) % 251 ) + 3
        end

        def call(env)
          myvm = env[:machine].id

          # only find network without :fowarded port, then sort by name label
          vifs = env[:machine].config.vm.networks.reject {
            |k,v| k == :forwarded_port}.sort_by {
              |k,v| v[:network] || ""}

          # this will hold any vifs with no device (ethX)
          vifs_unknown = []

          # create a placeholder hash for all vifs
          # note that eth0 is already used by HIMN, so start with 1
          eth = Hash.new
          vifs.count.times do |x|
            x += 1
            eth["eth#{x}".to_sym] = {}
          end

          # Get All networks without HIMN
          allnetworks = env[:xc].network.get_all_records.reject {
            |ref,net| net['other_config']['is_host_internal_management_network'] }

          # find the network type (public/external or private/single-server)
          allnets = {}
          allnetworks.each do |ref, params|
            allnets[ref] = params
            allnets[ref]["network_type"] = params["PIFs"].empty? ? "private_network" : "external_network"
          end
          # convert allnets to string for error message
          allnets_str = allnets.map { |k,v| "#{v['name_label']} (#{v['network_type']})"}.join(", ")

          # foreach vifs which has device defined, assign it to `eth` Hash
          vifs.each do |k,v|
            # Check if network name label in configuration matches
            # the network on Xenserver Host
            netrefrec = allnets.find { |ref,net| net['name_label'].upcase == v[:network].upcase }
            (net_ref, net_rec) = netrefrec
            if net_ref.nil?
              raise Errors::InvalidNetwork, network: v[:network], allnetwork: allnets_str, vm: env[:machine].name
            end

            # if not DHCP, and last IP octet is not integer, find available IP by trying to ping
            # next IP from its subnet based from a number which is a hash of its hostname
            if v[:proto] == "static"
              ip_part = v[:ip].rpartition(".")
              if not /\A\d+\z/.match(ip_part[2])
                v[:ip] = next_hashed_ip(env[:machine].name.to_s, ip_part[0])
              end
            end

            # Assign network UUID/ref
            v[:net_ref] = net_ref

            # Assign network type
            v[:network_type] = net_rec["network_type"]

            # no match, assign a device number (ethX) later
            if v[:device].nil?
              # vifs_unknown will contains vifs without :device defined
              # SORTED BY NETWORK NAME LABEL
              vifs_unknown.push(v)
            else
              if v[:device].start_with?("eth") and eth.include?(v[:device].to_sym)
                eth[v[:device].to_sym] = v
              else
                raise "Configration Error in netowrk `#{v[:network]}' for device name `#{v[:device]}'"
              end
            end
          end

          # Populate `eth' hash from the rest of unconfigured vifs
          vifs_unknown.each do |vif|
            unconfigured_eth = eth.find {|k,v| v.empty?}[0]
            vif[:device] = unconfigured_eth.to_s
            eth[unconfigured_eth.to_sym] = vif
          end

          # Validate network settings:
          #   - if `ip' and dhcp is set, raise error
          #   - ip and netmask must be defined it dhcp is not set
          #   - external_network
          #     - can have gateway
          #   - private_network (internal xenserver host-only network)
          #     - CANNOT have gateway
          #     - if `ip' defined, raise error if dhcp is set
          eth.each do |e, opt|
            raise Errors::InvalidInterface, eth: e, opt: opt[:proto], net: opt[:network],
              message: "No IP address is defined" if opt[:proto] == 'static' and opt[:ip].nil?

            raise Errors::InvalidInterface, eth: e, opt: opt[:proto], net: opt[:network],
              message: "No IP netmask is defined" if opt[:proto] == 'static' and opt[:netmask].nil?

            raise Errors::InvalidInterface, eth: e, opt: opt[:proto], net: opt[:network],
              message: "Cannot assign IP #{opt[:ip]} here" if opt[:proto] == 'dhcp' and !opt[:ip].nil?

            raise Errors::InvalidInterface, eth: e, opt: opt[:network_type], net: opt[:network],
              message: "Cannot assign gateway #{opt[:gateway]} here" if opt[:network_type] == "private_network" and !opt[:gateway].nil?
          end

          # Put eth on global env
          env[:vifs] = eth

          @app.call env
        end
      end
    end
  end
end
