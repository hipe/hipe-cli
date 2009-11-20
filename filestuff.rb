require File.dirname(__FILE__)+'/common'

module Hipe
  module FileStuff
    def self.file_must_exist(fn)
      unless File.exist?( fn )
        raise SoftException.new("file does not exist: "+fn)
      end
    end
    def self.file_must_not_exist(fn)
      if File.exist?( fn )
        raise SoftException.new("file must not already exist: "+fn)
      end
    end
  end
end