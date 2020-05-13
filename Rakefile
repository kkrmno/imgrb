require 'rake/testtask'
require 'rdoc/task'

require_relative 'lib/imgrb/version'

Rake::TestTask.new do |t|
	t.libs << 'test'
	t.verbose = false
end

desc "Run tests"
task :default => :test

# Generate documentation
Rake::RDocTask.new do |rd|
    rd.title = "Imgrb #{Imgrb::VERSION} - read and write png, apng, and bmp files"
    rd.main = "README.md"
    rd.rdoc_files.include("README.md", "lib/**/*.rb")
    rd.rdoc_dir = "rdoc"
end
