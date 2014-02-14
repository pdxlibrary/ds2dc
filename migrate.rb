#! /usr/bin/env ruby
# encoding: utf-8

require 'optparse'
require 'erb'
require 'csv'
require 'uri'
require 'nokogiri'
require 'htmlentities'
require 'logger'

class Author
  def initialize(options = {})
    self.first_name = options[:first_name] || ''
    self.last_name = options[:last_name] || ''
    self.middle_name = options[:middle_name] || nil
    self.email = options[:email] || nil
    self.institution = options[:institution] || nil
  end

  attr_accessor :first_name, :last_name, :middle_name, :institution, :email
end

## Below is the very poor use of a class
class Document

  attr_accessor :id, :title, :publication_date, :authors, :disciplines,
                :subject_areas, :keywords, :advisors, :abstract, :comments,
                :fulltext_url, :type, :issue, :department, :degree_name, 
                :degree_type, :format, :collection

  def derive_attachment_filename(location = '', collection_id = 0, item_id = 0)
    search_string = "//dcvalue[@qualifier='provenance']"
    dc_file_path = "#{location}/#{collection_id}/#{item_id}/dublin_core.xml"
    begin
      doc = Nokogiri::XML(File.open(dc_file_path)) 
    rescue
      puts "ERROR! #{dc_file_path} not found"
      exit
    end
    xml_line = doc.at_xpath(search_string)
    lines = xml_line.content.split('\n')
    attachment_filename, bytes, checksum = lines[2].split(':')
    attachment_filename
  end

  def initialize(row = '', collection_id = '', export_location = '')
    @collection = collection_id
    author_row = nil
    @authors = []

    if row['dc.contributor.author'] != '' and !row['dc.contributor.author'].nil?
      author_row = row['dc.contributor.author']
    elsif row['dc.contributor.author[]'] != '' and !row['dc.contributor.author[]'].nil?
      author_row = row['dc.contributor.author[]']   
    end

    if author_row.nil?
      @authors.push(Author.new(:first_name => 'Portland State University', :last_name => ''))
    else
      author_row.split('||').each do |author|
        a = author.split(', ')
        if a[1] =~ /\s/
          first, middle = a[1].split(' ')
          name = { :first_name => first, :middle_name => middle, :last_name => a[0] }
        else
          name = { :first_name => a[1], :last_name => a[0] }
        end
        @authors.push(Author.new(name))
      end
    end

    if row['dc.date.issued'] != '' and !row['dc.date.issued'].nil?
      date_row = row['dc.date.issued']
    elsif row['dc.date.issued[]'] != '' and !row['dc.date.issued[]'].nil?
      date_row = row['dc.date.issued[]']
    else
      date_row = nil
    end
    if date_row != '' and !date_row.nil?
      if date_row.chomp =~ /^[0-9]{2,4}-[0-9]{2,4}-[0-9]{2,4}$/
        @publication_date = date_row
      elsif date_row.chomp =~ /^[0-9]{1,4}\/[0-9]{2,4}\/[0-9]{2,4}$/
        @publication_date = date_row.gsub('/', '-')
      elsif date_row.chomp =~ /^[0-9]{2,4}-[0-9]{2,4}$/
        @publication_date = "#{date_row}-01"
      elsif date_row.chomp =~ /^[0-9]{1,4}\/[0-9]{2,4}$/
        @publication_date = "#{date_row}-01".gsub('/', '-')
      else
        @publication_date = "#{date_row}-01-01"
      end
    else
      @publication_date = '2014-01-01'
    end

    if row['dc.description.abstract[]'] != '' and !row['dc.description.abstract[]'].nil?
      @abstract = row['dc.description.abstract[]']
    else
      @abstract = row['dc.description.abstract[en_US]']
    end
    coder = HTMLEntities.new
    @abstract = coder.encode(@abstract)

    if row['dc.description[]'] != '' and !row['dc.description[]'].nil?
      @description = row['dc.description[]']
    else
      @description = row['dc.description[en_US]']
    end

    if row['dc.identifier.citation[]'] != '' and !row['dc.identifier.citation[]'].nil?
      @citation = row['dc.identifier.citation[]']
    else
      @citation = row['dc.identifier.citation[en_US]']
    end

    if row['dc.identifier.uri'] != '' and !row['dc.identifier.uri'].nil?
      @id = row['dc.identifier.uri'].split('/').last
    else
      @id = row['dc.identifier.uri[]'].split('/').last
    end

    if row['dc.subject.lcsh[en_US]'] != '' and !row['dc.subject.lcsh[en_US]'].nil?
      @subject_areas = row['dc.subject.lcsh[en_US]'].split('||')
    elsif row['dc.subject.lcsh[]'] != '' and !row['dc.subject.lcsh[]]'].nil?
      @subject_areas = row['dc.subject.lcsh[]'].split('||')
    end

    @title = row['dc.title[en_US]'].chomp

    if row['dc.type[]'] != '' and !row['dc.type[]'].nil?
      @type = row['dc.type[]'].chomp
    else
      unless row[16].nil?
        @type = row['dc.type[en_US]'].chomp
      end
    end

    # Attachment File
    file_name = derive_attachment_filename(export_location, collection_id, @id)
    @fulltext_url = URI::encode("#{options[:url_base]}/#{collection_id}/#{@id}/#{file_name}") unless file_name.nil?

  end

  def to_xml(template = '', target = '')
    if template.nil?
      exit 1
    end
    template_file = File.open(template, 'r').read
    erb = ERB.new(template_file)
    File.open(target, 'w+') { |file|
      file.write(erb.result(binding))
    }
  end

end

options = {}
opts = OptionParser.new do |parser|
  parser.banner = 'Usage: migrate.rb [options]'
  parser.separator ''
  parser.on('-m', '--metadata_file FILENAME', 'CSV file containing DSpace metadata') do |metadata_file|
    options[:metadata_file] = metadata_file
  end
  parser.on('-e', '--export_location FILENAME', 'Location of DSpace export bundles') do |export_location|
    options[:export_location] = export_location
  end
  parser.on('-c', '--collection_id FILENAME', 'DSpace collection ID, excluding institutional prefix') do |collection_id|
    options[:collection_id] = collection_id
  end
  parser.on('-d', '--department_name DEPARTMENT', 'Department name (optional)') do |department_name|
    options[:department_name] = department_name
  end
  parser.on('-u', '--url_base URL', 'Base URL for Digital Commons to retrieve static assets') do |url_base|
    options[:url_base] = url_base
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
if options[:metadata_file].nil? or options[:export_location].nil? or options[:collection_id].nil? or options[:url_base].nil?
  raise OptionParser::MissingArgument, 'Use ./merge-accounts.rb -h for an argument list.' 
end

## Set logging - the target should probably be configurable
log = Logger.new(STDOUT)
if options[:debug]
  log.level = Logger::DEBUG
else
  log.level = Logger::INFO
end

## Dump command-line arguments
log.debug("\nMETADATA FILE: #{options[:metadata_file]}")
unless options[:department_name].nil?
  log.debug("DEPARTMENT NAME: #{options[:department_name]}")
end
log.debug("EXPORT LOCATION: #{options[:export_location]}")
log.debug("URL BASE: #{options[:url_base]}")
log.debug("COLLECTION ID: #{options[:collection_id]}")


## It's business time
@documents = []
CSV.foreach("#{options[:metadata_file]}", :headers => true) do |row|
  if row[0] != 'id'
    @documents.push(Document.new(row, options[:collection_id], options[:export_location]))
  end
end

template_file = File.open('import-template.xml.erb', 'r').read
erb = ERB.new(template_file, nil, '-') 
if options[:department_name].nil?
  out_file = "#{options[:collection_id]}-metadata.xml"
else
  out_file = "#{options[:department_name]}-#{options[:collection_id]}-metadata.xml"
end

File.open(out_file, 'w+') do |file|
  file.write(erb.result(binding))
end