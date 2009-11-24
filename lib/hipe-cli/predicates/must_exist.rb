module Hipe::Cli::Predicates
  def must_exist(validation_data, var_hash, var_name)
    unless File.exist?( fn )
      raise SoftException.new("file does not exist: "+fn)
    end
  end
end