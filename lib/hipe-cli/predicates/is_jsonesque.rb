module Hipe::Cli::Predicate
  # this guy makes string keys and string values!
  # pls note that according to apeiros in #ruby, "your variant of json isn't json"
  def jsonesque(validation_data, var_hash, var_name)
    var_hash[var_name] = Hash[*(var_hash[var_name]).split(/:|,/)] # thanks apeiros
  end
end
