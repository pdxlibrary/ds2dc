#! /usr/bin/env ruby
# encoding: utf-8

# Extract URI from XML Dublin Core metadata file.

require 'optparse'
require 'logger'
require 'nokogiri'
 
dc_terms = [ :identifier, :uri ]
search_string = "//dcvalue[@qualifier='uri']"

options = {}
opts = OptionParser.new do |parser|
  parser.banner = 'Usage: rename-exported-bundles.rb [options]'
  parser.separator ''
  parser.on('-b', '--bundle_location FOLDER', 'Location of bundles exported from DSpace') do |bundle_location|
    options[:bundle_location] = bundle_location
  end
  parser.on('-g', '--debug', 'Enable debug logging') do |debug|
    options[:debug] = true
  end
  parser.on_tail('-h', '--help', 'Display this screen') do |help|
    puts parser.help
    exit
  end
end

## Validate command-line arguments
opts.parse!(ARGV)
if options[:bundle_location].nil?
  raise OptionParser::MissingArgument, 'Use ./rename-exported-bundles.rb -h for an argument list.' 
end

## Set logging - the target should probably be configurable
log = Logger.new(STDOUT)
if options[:debug]
  log.level = Logger::DEBUG
else
  log.level = Logger::INFO
end

xf = File.join("**", "dublin_core.xml")
xml_files = Dir.chdir(options[:bundle_location]) { Dir.glob(xf).map{ |x| File.expand_path(x) } }

xml_files.each do |x|
  puts "Searching #{x}..."
  xml_file = File.open(x)
  doc = Nokogiri::XML(xml_file)
  id = doc.at_xpath(search_string).content.split("/").last
  puts "\tID: #{id}"
  xml_file.close
  log.debug("DIRECTORY: #{File.dirname(x)}")
  log.debug("PARENT: #{File.expand_path("../..", x)}")
  log.debug("RENAME TO: #{File.expand_path("../..", x)}/#{id}")
  File.rename File.dirname(x), "#{File.expand_path("../..", x)}/#{id}"
end

