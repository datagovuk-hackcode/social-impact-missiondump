# spec/spec_helper.rb
require 'rspec'
require 'rack/test'
require File.expand_path 'app'

module RSpecMixin
  include Rack::Test::Methods
  def app() Sinatra::Application end
end

# For RSpec 2.x
RSpec.configure { |c| c.include RSpecMixin }