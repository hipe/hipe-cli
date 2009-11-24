module Hipe::Cli::Predicates
  def gets_opened action, var_hash, var_name
    @cli_files[var_name] = {
      :fh => File.open(var_hash[var_name], action[:as]),
      :filename => var_hash[var_name]
    }      
  end
end