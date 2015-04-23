srcdir = File.expand_path("../../src", __FILE__)
y2dirs = ENV.fetch("Y2DIR", "").split(":")
ENV["Y2DIR"] = y2dirs.unshift(srcdir).join(":")

require_relative "matchers"
RSpec.configure do |c|
  c.include Yast::RSpec::Matchers
end

def path(s)
  Yast::Path.new(s)
end
