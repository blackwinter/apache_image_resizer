$:.unshift('lib') unless $:.first == 'lib'

require 'apache/image_resizer'
require 'apache/mock_constants'

RSpec.configure { |config|
  %w[expect mock].each { |what|
    config.send("#{what}_with", :rspec) { |c| c.syntax = [:should, :expect] }
  }
}
