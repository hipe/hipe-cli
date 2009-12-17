#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),'../lib/'))
require 'hipe-cli'
require 'hipe-core/io/golden-hammer'

class AppIt3
  include Hipe::Cli
  cli.does('-h','--help')
  cli.default_command = 'help'
  cli.does('order-sandwich'){
    option('-o','--num-olives NUM',"the number of olives you want on it. %generated_description%", :default=>'3'){|it|
      it.must_match_range(0..12).must_be_integer
    }
    option('-t','--topping TOPPING',['mustard','ketchup','mayonaise'])
    required('name', 'the name of the customer'){|it|
      it.must_match_regexp(/^[a-z][- a-z]*$/i,%{Sorry, "%provided_value%" does not appear to be a valid name.})
    }
    optional('bread',['rye','white','whole wheat'],'',:default=>'white')
  }
  def order_sandwich(name,bread,opts)
    @stack = ['done.']
    @stack.push %{  slice of bread: #{bread}}
    unless 0 == opts.num_olives
      @stack.push %{    olives: #{opts.num_olives} ct.}
    end
    if (opts.topping)
      toppings = opts.topping
      toppings = [toppings] unless Array === opts.topping
      toppings.each do |val|
        @stack.push %{    topping: #{val}}
      end
    end
    @stack.push %{  slice of bread: #{bread}}
    @stack.push %{your sandwich:}
    @stack.reverse.join "\n"
  end
  cli.does(:laundry,%{the output of this might not make sense. it's just for tests}){
    required(:in_file){|it|
      it.must_exist!()
      it.gets_opened('r')
    }
    required(:out_file){|it|
      it.must_not_exist!()
      it.gets_opened('w+')
    }
  }
  def laundry(infile,outfile)
    s = %{input filename: #{infile.filename}, output filename: #{outfile.filename}\n}
    bytes = outfile.fh.write(infile.fh.read)
    s << %{wrote #{bytes} bytes to outfile.}
    infile.fh.close
    outfile.fh.close
    s
  end
end

puts AppIt3.new.cli.run(ARGV) if $PROGRAM_NAME == __FILE__

