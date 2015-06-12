srcdir = File.expand_path("../../src", __FILE__)
y2dirs = ENV.fetch("Y2DIR", "").split(":")
ENV["Y2DIR"] = y2dirs.unshift(srcdir).join(":")

require "yast/rspec"

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.configure do
    # Don't measure the tests themselves. We should have named them /spec/.
    add_filter "/test/"
  end
  SimpleCov.start

  # for coverage we need to load all ruby files
  src_location = File.expand_path("../../src", __FILE__)
  # note that clients/ are excluded because they run too eagerly by design
  Dir["#{src_location}/{include,modules}/**/*.rb"].each do |f|
    require_relative f
  end

  # use coveralls for on-line code coverage reporting at Travis CI
  if ENV["TRAVIS"]
    require "coveralls"
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      Coveralls::SimpleCov::Formatter
    ]
  end
end
