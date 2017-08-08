require "vagrant"

module VagrantPlugins
  module XenServer
    module Errors
      class VagrantXenServerError < Vagrant::Errors::VagrantError
        error_namespace("vagrant_xenserver.errors")
      end

      class LoginError < VagrantXenServerError
        error_key(:login_error)
      end

      class UploaderInterrupted < VagrantXenServerError
        error_key(:uploader_interrupted)
      end

      class UploaderError < VagrantXenServerError
        error_key(:uploader_error)
      end

      class APIError < VagrantXenServerError
        error_key(:api_error)
      end

      class UnknownOS < VagrantXenServerError
        error_key(:unknown_os)
      end

      class QemuImgError < VagrantXenServerError
        error_key(:qemuimg_error)
      end

      class NoDefaultSR < VagrantXenServerError
        error_key(:nodefaultsr_error)
      end

      class NoHostsAvailable < VagrantXenServerError
        error_key(:nohostsavailable_error)
      end

      class Import404 < VagrantXenServerError
        error_key(:import404)
      end

      class InvalidNetwork < VagrantXenServerError
        error_key(:invalid_network)
      end

      class InvalidInterface < VagrantXenServerError
        error_key(:invalid_interface)
      end

      class InsufficientSpace < VagrantXenServerError
        error_key(:insufficientspace)
      end

      class ConnectionError < VagrantXenServerError
        error_key(:connection_error)
      end

      class HIMNCommunicatorError < VagrantXenServerError
        error_key(:himn_communicator_error)
      end
      
      class CannotAllocateAddress < VagrantXenServerError
        error_key(:allocate_address_error)
      end
      
    end
  end
end
