require "log4r"
require "xmlrpc/client"

module VagrantPlugins
  module XenServer
    module Action
      class HaltVM
        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new("vagrant::xenserver::actions::halt_vm")
        end

        def shutdown(xc, vm)
          begin
            Timeout::timeout(15) do
              xc.VM.clean_shutdown(vm)
            end
          rescue Timeout::Error, StandardError
            puts "hard"
            xc.VM.hard_shutdown(vm)
          end
        end

        def call(env)
          shutdown env[:xc], env[:machine].id
          @app.call env
        end
      end
    end
  end
end
