class SomePlugin
  include Hipe::Cli::App
  
  cli.does :go_daddy, {
    
  }
  
  def go_daddy
    puts "i'm going"
  end
  
end