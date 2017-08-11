require 'nokogiri'
require 'socket'
require 'rbconfig'
require 'net/ping/external'

def os
    @os ||= (
      host_os = RbConfig::CONFIG['host_os']
      case host_os
      when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
        :windows
      when /darwin|mac os/
        :macosx
      when /linux/
        :linux
      when /solaris|bsd/
        :unix
      else
        raise Vagrant::Errors::UnknownOS # "unknown os: #{host_os.inspect}"
      end
    )
  end


module VagrantPlugins
  module XenServer
    module Action
      class PrepareNFSSettings
        include Vagrant::Action::Builtin::MixinSyncedFolders
        
        def initialize(app,env)
          @app = app
          @logger = Log4r::Logger.new("vagrant::action::vm::nfs")
        end

        def call(env)
          @machine = env[:machine]
          @app.call(env)          

          if using_nfs?
            @logger.info("Using NFS, preparing NFS settings by reading host IP and machine IP")
            env[:nfs_host_ip] = read_host_ip(env[:machine],env)

            public_network_defined = false
            vm_ip = nil

            # check if there is public_network defined in Vagrantfile
            # pick the one which is routable, and return
            env[:machine].config.vm.networks.each do |ntype, net|
              next if ntype == :forwarded_port or ntype == :private_network
              public_network_defined = true

              # Find which network has the network name match in Vagrantfile and is routable
              # :ip_raw can be exists if using notation 10.0.0.X (no digit in last octet)
              if net[:proto] == "static" and !net[:ip_raw].nil?
                if not /\A\d+\z/.match(net[:ip_raw].rpartition(".")[2]).nil?
                  if ping(net[:ip])
                    vm_ip = net[:ip]
                    env[:nfs_machine_ip] = vm_ip
                    break
                  end
                end
              end
              # This is dhcp / using X notation as last IP octet. Let's find out
              # Get VM record
              @vm ||= env[:xc].VM.get_record(env[:machine].id)
              # Get all Networks
              @networks ||= env[:xc].network.get_all_records
              # Get guest network metrics
              @guest_metrics ||= env[:xc].VM_guest_metrics.get_networks(env[:xc].VM.get_guest_metrics(env[:machine].id))
              # Find vm networks which match machine config
              vm_net = @networks.find { |k,v| v['name_label'].upcase == net[:network].upcase }
              vm_vif = vm_net[1]['VIFs'].find { |v| @vm['VIFs'].include? v }
              # Find the VIF's "device" number, e.g. device 2 is eth2 in a centos guest
              vif = env[:xc].VIF.get_record(vm_vif)
              # Get the IP
              ip = @guest_metrics[vif["device"] + "/ip"]
              if ping(ip)
                vm_ip = ip
                env[:nfs_machine_ip] = vm_ip
                break
              end
            end

            # public_network defined, but unreachable or has no IP
            raise Vagrant::Errors::NFSNoGuestIP if public_network_defined && vm_ip.nil?
            # no public_network but invalid nfs_host_ip
            raise Vagrant::Errors::NFSNoHostonlyNetwork if !env[:nfs_machine_ip] || !env[:nfs_host_ip]

            @logger.info("host IP: #{env[:nfs_host_ip]} machine IP: #{env[:nfs_machine_ip]}")
          end
        end

        # We're using NFS if we have any synced folder with NFS configured. If
        # we are not using NFS we don't need to do the extra work to
        # populate these fields in the environment.
        def using_nfs?
          !!synced_folders(@machine)[:nfs]
        end

        # Returns the IP address of the interface that will route to the xs_host
        #
        # @param [Machine] machine
        # @return [String]
        def read_host_ip(machine,env)
          ip = Socket.getaddrinfo(env[:machine].provider_config.xs_host,nil)[0][2]
          env[:xs_host_ip] = ip
          def get_local_ip_linux(ip)
            re = /src ([0-9\.]+)/
            match = `ip route get to #{ip} | head -n 1`.match re
            match[1]
          end
          def get_local_ip_mac(ip)
            re = /interface: ([a-z0-9]+)/
            match = `route get #{ip} | grep interface | head -n 1`.match re
            interface = match[1]
            re = /inet ([0-9\.]+)/
            match = `ifconfig #{interface} inet | tail -1`.match re
            match[1]
          end
          def get_local_ip_win(ip)
            # Assume default gateway interface has IP address which reachable from Xenserver Host
            re = /^.*0\.0\.0\.0\s+\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}).*$/
            match = `route -4 PRINT 0.0.0.0`.match re
            match[1]
          end
          if os == :linux then get_local_ip_linux(ip)
          elsif os == :macosx then get_local_ip_mac(ip)
          elsif os == :windows then get_local_ip_win(ip)
          else raise Vagrant::Errors::UnknownOS # "unknown os: #{host_os.inspect}"
          end
        end

        # Check if we can open a connection to the host
        def ping(host)
          check = Net::Ping::External.new(host)
          check.timeout = 3
          check.ping?
        end
      end
    end
  end
end
