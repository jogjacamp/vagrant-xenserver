require "log4r"

module VagrantPlugins
  module XenServer
    module Action
      # This action wait for SSH Communicator via HIMN interface is ready
      class WaitForHIMNCommunicator
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_xenserver::action::wait_himn")
        end

        def call(env)
          if env[:machine].provider_config.use_himn
            env[:machine_ssh_info] = wait_ssh_via_himn(env)
          end

          @app.call(env)
        end

        def wait_ssh_via_himn(env)
          machine = env[:machine]
          return nil if machine.id.nil?

          # Find the machine
          networks = env[:xc].network.get_all_records

          begin
            vifs = env[:xc].VM.get_VIFs(machine.id)
          rescue
            @logger.info("Machine couldn't be found, assuming it got destroyed.")
            machine.id = nil
            return nil
          end

          himn = networks.find { |ref,net| net['other_config']['is_host_internal_management_network'] }
          (himn_ref,himn_rec) = himn

          assigned_ips = himn_rec['assigned_ips']
          (vif,ip) = assigned_ips.find { |vif,ip| vifs.include? vif }

          command = "ssh '#{machine.provider_config.xs_host}' -l '#{machine.provider_config.xs_username}' \"true &>/dev/null </dev/tcp/#{ip.to_s}/22 && echo open || echo closed\""
          # XXX: Issue #1 https://github.com/jogjacamp/vagrant-xenserver/issues/1
          # TODO: For now, just sleep 20 seconds :D *evil grind*
          sleep 20

        end

      end
    end
  end
end
