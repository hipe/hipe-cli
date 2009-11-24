module Hipe::Cli::Options
  def debug
    {
      :description => 'Type one or more d\'s (e.g. "-ddd" to indicate varying degrees of '+
      'debugging output (put to $stderr).',
      :getopt_type => Getopt::INCREMENT,
      :getopt_letter => 'd'
    }
  end
end
