require "log4r"
require "xmlrpc/client"
require "vagrant-xenserver/util/uploader"
require "rexml/document"
require "json"

module VagrantPlugins
  module XenServer
    module Action
      # This action will tell vagrant to activate configure_networks capability
      # Interface configuration for a VM must be defined first in env[:vifs]
      class ConfigureNetwork
        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new("vagrant::xenserver::actions::configure_network")
        end

        def call(env)
          # Get machine first.
          myvm = env[:machine].id

          # Configure interfaces that user requested. Machine should be up and
          # running now.
          @logger.info("Configuring guest network")
          env[:ui].output(I18n.t("vagrant.actions.vm.network.preparing"))
          networks_to_configure = []

          env[:vifs].each do |eth, option|
            network = {
              :interface => eth[-1, 1].to_i,
              :type      => option[:proto]
            }

            network[:ip] = option[:ip]
            network[:netmask] = option[:netmask]
            network[:gateway] = option[:gateway]

            static_str = option[:ip].nil? ? "" : " / #{option[:ip]}"

            env[:ui].detail(I18n.t(
              "vagrant.virtualbox.network_adapter",
              adapter: "#{eth} (#{option[:proto]}#{static_str})",
              type: "#{option[:network_type]}",
              extra: " on network #{option[:network]}",
            ))

            networks_to_configure << network
          end

          env[:ui].info I18n.t("vagrant.actions.vm.network.configuring")
          env[:machine].guest.capability(
            :configure_networks, networks_to_configure)

          # Continue the middleware chain.
          @app.call(env)

        end
      end
    end
  end
end
