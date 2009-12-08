module Hipe
  module Cli
    module PredicateLike
      @listens_for = {}
      class << self
        attr_accessor :listens_for
      end
      module ClassMethods
        def listens_for (*symbol_list)
          symbol_list.each do |symbol|
            PredicateLike.listens_for[symbol] ||= []
            PredicateLike.listens_for[symbol] << self
          end
        end
      end
      def self.included(klass)
        klass.extend ClassMethods
      end
    end
    class PredicateEngine
      def initialize request
        @request = request
        @all_ks = PredicateLike.listens_for.keys
      end # works like a flyweight with init(). be careful!
      def run_predicates element, parameter_name
        if (@request[parameter_name].instance_of? Array)
          splat = @request[parameter_name]          
          engine = self.class.new(splat)
          (0..splat.size-1).each do |i|
            engine.run_predicates(element,i)
          end
          return  
        end
        if (element.nil?)
          raise 'no'
        end
        do_these = (element.keys & @all_ks)
        do_these += element[:it] if element[:it]
        do_these += element[:they] if element[:they]
        if do_these.size > 0
          do_these.each do |predicate_name|
            classes = PredicateLike.listens_for[predicate_name]
            # raise HardException.new("unrecognized predicate: #{predicate_name}") unless classes
            classes.each do |klass|
              predicate = klass.new
              predicate.execute element, @request, parameter_name
            end
          end
        end
      end
    end

    # Predicates can be both assertions about the validity of arguments, and actions
    # carried out on the arguments.  An example of both is a regexp with captures.
    # Such a predicate says "the parameter must match this regexp" and
    # "replace the parameter with these captured subexpressions."
    # example:  {:regexp=>/^version(\d\.\d.\d)/, :regexp_sentence=>"It must be a valid version number."}
    # Because they can change the state of the parameter, the sometimes need to
    # occur in a certain order.  This is what the :it subelement (array) is for.
    # for example {:type=>:file, :it=>[:must_exist, :gets_opened]}
    module Predicates

      # for files, open the file ()
      class GetsOpened
        include PredicateLike
        listens_for :gets_opened
        def execute element, request, parameter_name
          filename = request[parameter_name]
          mode = File.exist?(filename) ? 'r+' : 'w'
          request[parameter_name] = {
            :fh => File.open(filename, mode),
            :filename => filename
          }
        end
      end

      # for files, throws a ValidationFailure unless the file exists
      class MustExist
        include PredicateLike
        listens_for :must_exist
        def execute element, request, parameter_name
          fn = request[parameter_name]
          unless File.exist? fn
            raise ValidationFailure.factory(%{#{element.title} file does not exist: "#{fn}"},
              :type=>:file_must_exist, :file=>fn, :element=>element
            )
          end
        end
      end

      # for files, throw a validation failure if the file with the parameter name exists
      class MustNotExist
        include PredicateLike
        listens_for :must_not_exist
        def execute element, request, parameter_name
          fn = request[parameter_name]
          if File.exist? fn
            raise ValidationFailure.factory(%{#{element.title} exists, must not: "#{fn}"},
              :type=>:file_must_not_exist, :file=>fn, :element=>element
            )
          end
        end
      end

      # parse the string using the "jsonesque" pseudo syntax#
      # this is left here for posterity but
      # it's quite ugly to pass jsonesque parameters as values to command line options or arguments ;)
      class IsJsonesque # apeiros: "your variant of json isn't json" ;)
        include PredicateLike
        listens_for :is_jsonesque
        def execute element, request, parameter_name
          str = request[parameter_name]
          res = str.split(/:|,/)
          raise ValidationFailure.factory(%{#{element.title} is an invalid jsonesque string: "#{str}"},{}) if (res.size % 2) != 0
          request[parameter_name] = Hash[*res] # thanks apeiros
        end
      end

      # assert that the parameter value matches the regexp, throw a ValidationFailure if not.
      # if the regepx has any captures then the resulting parameter value will be the captures list for the regexp
      # note that this means that if your regexp has any captures then you will parts that are not captured
      # if the regexp does not have any captures then the request parameter is left alone
      class Regexp
        include PredicateLike
        listens_for :regexp
        def execute element, request, parameter_name
          value = request[parameter_name]
          re = element[:regexp]
          unless matches = re.match(value.to_s) #to_s incase we accidentally turn regexp against an :increment
            msg = element[:regexp_sentence] || "failed to match against regular expression #{re}"
            msg.gsub!(/^it\b/i, element.title) # @hack
            raise ValidationFailure.factory(msg, :type=>:regexp_failure,
              :regexp=>re, :element=>element
            )
          end
          # clobbers original, only when there are captures !
          request[parameter_name] = matches.captures if matches.size > 1
        end
      end

      class Float
        include PredicateLike
        listens_for :float
        def execute element, request, parameter_name
          val = request[parameter_name]
          unless /^-?\d+(?:\.\d+)?$/ =~ val
            raise ValidationFailure.factory(
              %{#{element.title} must be a number, not "#{val}"},
              :type => :float_failure, :element => element, :provided => val
            )
          end
          request[parameter_name] = val.to_f
        end
      end

      class Range
        include PredicateLike
        listens_for :range
        def execute element, request, parameter_name
          Float.new().execute element, request, parameter_name
          value = request[parameter_name]
          range = element[:range]
          unless element[:range] === value
            msg = %{#{element.title} must be within the range #{range.begin} - #{range.end}}
            raise ValidationFailure.factory(msg, :type=>:range_failure,
              :range => range, :element=>element
            )
          end
        end
      end
    end # Predicates
  end # Cli
end # Hipe