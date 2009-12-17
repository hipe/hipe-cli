require 'ruby-debug'
require 'bacon'
unless $:.grep(/hipe-cli/).size > 0
  $LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'../lib/'))
  require 'hipe-cli'
end
require 'hipe-core/test/bacon-extensions'


module Hipe
  def self.shell!(string)  # @TODO huge security hole? just for writing tests
    rs = %x{hipe-cli-argv-echo #{string}}
    Marshal.load(rs)
    #require 'open3'                 the below doesn't work b/c popen3 escapes the string into one argument
    #Open3.popen3('hipe-cli-argv-echo',string) do |sin, sout, serr|
    #  out = sout.read
    #  err = serr.read.strip
    #  raise err if err.length > 0
    #end
  end

  module Test
    class Helper
      @singletons = {}
      attr_reader :writable_tmp_dir
      def self.singleton(project_module)
        @singletons[project_module] ||= self.new(project_module)
      end
      def initialize(project_module)
        @project_module = project_module
        @writable_tmp_dir = File.join(project_module.const_get('DIR'), 'spec','writable-tmp')
      end
      def clear_writable_tmp_dir!
        dirpath = @writable_tmp_dir
        raise %{something looks wrong with writable_tmp_dir name: "#{dirpath}"} unless dirpath =~ /writable-tmp$/
        raise %{"#{dirpath}" must exist} unless File.exist?(dirpath)
        raise %{"#{dirpath}" must be writable} unless File.writable?(dirpath)
        Dir[File.join(dirpath,'/*')].each do |filename|
          File.unlink(filename)
        end
      end
    end
  end
end
