require 'daitss/proc/template/descriptor'
require 'daitss/proc/template/premis'
require 'daitss/proc/wip/from_aip'
require 'daitss/proc/wip/preserve'
require 'daitss/proc/wip/tarball'
require 'daitss/proc/wip/to_aip'
require 'daitss/proc/xmlvalidation'

module Daitss

  class Wip

    def disseminate
      step('load from aip') { load_from_aip }
      preserve

      step 'disseminate digiprov'  do
        metadata['disseminate-event'] = disseminate_event package, next_event_index('disseminate')
        metadata['disseminate-agent'] = system_agent
      end

      step('make aip descriptor') { make_aip_descriptor }
      step('validate aip descriptor') { validate_aip_descriptor }
      step('make tarball') { make_tarball }
      step('make aip') { update_aip }

      step 'deliver dip' do
        set_drop_path
        FileUtils.cp tarball_file, drop_path
      end

    end

    def drop_path
      @info['drop-path']
    end

    def set_drop_path
      @info['drop-path'] = next_drop_path
      save_info
    end

    def next_drop_path
      pattern = File.join archive.disseminate_path, "#{id}-*.tar"
      dips = Dir[pattern]

      n = if dips.empty?
            0
          else
            dips.map { |f| File.basename(f)[%r{#{id}-(\d+).tar}, 1].to_i }.max + 1
          end

      File.join archive.disseminate_path, "#{id}-#{n}.tar"
    end

  end

end
