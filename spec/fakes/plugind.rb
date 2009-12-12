class Plugind
  include Hipe::Cli::App
  cli.does :wankzorzz
  def wankzorzz 
    cli.out.puts "yes it is a wankzorzz"
  end
end
