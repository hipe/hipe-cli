module Hipe::Cli::Validators  
  def must_match_regexp(validation_data, var_hash, var_name)
    value = var_hash[var_name]  
    re = validation_data[:regexp]
    if (! matches = (re.match(value.to_s))) 
      # the only time we should need to_s is when this accidentally turned against an INCREMENT value
      msg = validation_data[:message] || "failed to match against regular expression #{re}"
      raise SyntaxError.new(%{Error with --#{var_name}="#{value}": #{msg}})
    end
    var_hash[var_name] = matches.captures if matches.size > 1 # clobbers original, only when there are captures ! 
  end
end