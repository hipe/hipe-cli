module Hipe
  module Cli    
    # The individual instance of something the user entered.
    class Command < Hash
      @validity_is_known = false
      @errors = []  
    end
    
    def self.[](hash)
      hash = hash.clone
      %w(options required optionals splat).map{|x| x.to_sym}.each do |thing|
        self[thing] = hash.delete(thing)
      end
      self[:extra] = hash
    end
  end # Cli
end # Hipe