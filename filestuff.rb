require File.dirname(__FILE__)+'/common'

module Markus
  module FileStuff
    def self.file_must_exist(fn)
      unless File.exist?( fn )
        raise SoftException.new("file does not exist: "+fn)
      end
    end
  end
end