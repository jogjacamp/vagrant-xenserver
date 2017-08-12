require 'log4r'
require 'net/ping/external'


module VagrantPlugins
  module XenServer
    module Action
      class ReadIP
        def initialize(app, env, *opts)
          @app = app
          @logger = Log4r::Logger.new('vagrant_xenserver::action::read_ip')
          @opts = opts
        end

        def call(env)
          @app.call(env)
          vm_ip = nil
          gm = env[:xc].VM.get_guest_metrics(env[:machine].id)
          max_retry = @opts.include?(:wait) ? 60 : 0
          begin
            retries ||= 0
            env[:xc].VM_guest_metrics.get_networks(gm).reject{
            |k,v| v.start_with?"169.254" or !k.end_with?"/ip" }.each do |_, ip|
              vm_ip = ip
              break
            end
            sleep 1
            raise if vm_ip.nil?
          rescue
            if retries == max_retry and @opts.include? :wait
              raise Errors::ReadIPError
            end
            retry if (retries += 1) <= max_retry
          end


          env[:machine_ip_seen] = vm_ip
        end
      end
    end
  end
end
