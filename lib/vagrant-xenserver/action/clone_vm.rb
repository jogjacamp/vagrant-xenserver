require "log4r"
require "xmlrpc/client"

module VagrantPlugins
  module XenServer
    module Action
      class CloneVM
        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new("vagrant::xenserver::actions::clone_vm")
        end

        def call(env)
          template_ref = env[:template]
          username = Etc.getlogin
          vm_name = "#{username}/#{env[:machine].name}"
          vm = nil
          Action.getlock.synchronize do
            vm = env[:xc].VM.clone(template_ref, vm_name)
            env[:xc].VM.provision(vm)
          end

          env[:machine].id = vm

          @app.call env
        end
      end
    end
  end
end
