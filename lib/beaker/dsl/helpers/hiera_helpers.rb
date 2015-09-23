module Beaker
  module DSL
    module Helpers
      # Methods that help you interact with your hiera installation, hiera must be installed
      # for these methods to execute correctly
      module HieraHelpers

        # Write hiera config file on one or more provided hosts
        #
        # @param[Host, Array<Host>, String, Symbol] host    One or more hosts to act upon,
        #                           or a role (String or Symbol) that identifies one or more hosts.
        # @param[Array] One or more hierarchy paths
        def write_hiera_config_on(host, hierarchy)

          block_on host do |host|
            hiera_config=Hash.new
            hiera_config[:backends] = 'yaml'
            hiera_config[:yaml] = {}
            hiera_config[:yaml][:datadir] = hiera_datadir(host)
            hiera_config[:hierarchy] = hierarchy
            hiera_config[:logger] = 'console'
            create_remote_file host, host.puppet['hiera_config'], hiera_config.to_yaml
          end
        end

        # Write hiera config file for the default host
        # @see #write_hiera_config_on
        def write_hiera_config(hierarchy)
          write_hiera_config_on(default, hierarchy)
        end

        # Set things up for the inline hieradata functions 'set_hieradata_on'
        # and 'clear_temp_hieradata'
        #
        #
        RSpec.configure do |c|
          c.before(:all) do
            @temp_hieradata_dirs = @temp_hieradata_dirs || []
          end

          c.after(:all) do
            clear_temp_hieradata
          end
        end
        
        # Set the hiera data file on the provided host to the passed data structure
        #
        # Note: This is authoritative, you cannot mix this with other hieradata copies
        #
        # @param[Host, Array<Host>, String, Symbol] One or more hosts to act upon.
        #
        # @param[Hieradata, Hash] The full hiera data structure to write to the system.
        #
        # @param[Data_file, String] The filename (not path) of the hiera data
        #                           YAML file to write to the system.
        #
        # @param[Hiera_config, Array<String>] The hiera config array to write
        #                                     to the system. Must contain the
        #                                     Data_file name as one element.
        def set_hieradata_on(host, hieradata, data_file='default')
          # Keep a record of all temporary directories that are created
          #
          # Should be cleaned by calling `clear_temp_hiera data` in after(:all)
          #
          # Omit this call to be able to delve into the hiera data that is
          # being created
          @temp_hieradata_dirs ||= @temp_hieradata_dirs = []
      
          data_dir = Dir.mktmpdir('hieradata')
          @temp_hieradata_dirs << data_dir
      
          fh = File.open(File.join(data_dir,"#{data_file}.yaml"),'w')
          fh.puts(hieradata.to_yaml)
          fh.close
      
          copy_hiera_data_to(host, data_dir)
          write_hiera_config_on(host, Array(data_file))
        end

        # Clean up all temporary hiera data files.
        #
        # Meant to be called from after(:all)
        def clear_temp_hieradata
          if @temp_hieradata_dirs && !@temp_hieradata_dirs.empty?
            @temp_hieradata_dirs.each do |data_dir|
              FileUtils.rm_r(data_dir)
            end
          end
        end 
        
        #
        # Copy hiera data files to one or more provided hosts
        #
        # @param[Host, Array<Host>, String, Symbol] host    One or more hosts to act upon,
        #                           or a role (String or Symbol) that identifies one or more hosts.
        # @param[String]            Directory containing the hiera data files.
        def copy_hiera_data_to(host, source)
          # If there is already a directory on the system, the SCP below will
          # add the local directory to the existing directory instead of
          # replacing the contents.
          apply_manifest_on(
            host,
            "file { '#{hiera_datadir(host)}': ensure => 'absent', force => true, recurse => true }"
          ) 

          scp_to host, File.expand_path(source), hiera_datadir(host)
        end

        # Copy hiera data files to the default host
        # @see #copy_hiera_data_to
        def copy_hiera_data(source)
          copy_hiera_data_to(default, source)
        end

        # Get file path to the hieradatadir for a given host.
        # Handles whether or not a host is AIO-based & backwards compatibility
        #
        # @param[Host] host Host you want to use the hieradatadir from
        #
        # @return [String] Path to the hiera data directory
        def hiera_datadir(host)
          host[:type] =~ /aio/ ? File.join(host.puppet['codedir'], 'hieradata') : host[:hieradatadir]
        end

      end
    end
  end
end
