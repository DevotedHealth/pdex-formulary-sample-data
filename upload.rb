require 'pry'
require 'git'
require 'zip'
require 'httparty'
require 'tmpdir'
require 'fileutils'

FHIR_SERVER = 'http://localhost:8080/plan-net/fhir'
BATCH_SIZE = 100

def upload_conformance_resources
  definitions_url = 'http://build.fhir.org/ig/HL7/davinci-pdex-formulary/definitions.json.zip'
  definitions_data = HTTParty.get(definitions_url, verify: false)
  definitions_file = Tempfile.new
  begin
    definitions_file.write(definitions_data)
  ensure
    definitions_file.close
  end

  resources = {}

  Zip::File.open(definitions_file.path) do |zip_file|
    zip_file.entries
      .select { |entry| entry.name.end_with? '.json' }
      .reject { |entry| entry.name.start_with? 'ImplementationGuide' }
      .each do |entry|
        resource = JSON.parse(entry.get_input_stream.read, symbolize_names: true)
        
        # aggregate resources
        resources[resource[:resourceType]] = [] unless resources.key?(resource[:resourceType])
        resources[resource[:resourceType]].push(resource)

        if resources[resource[:resourceType]].length() >= BATCH_SIZE
          puts "uploading batch of #{resources[resource[:resourceType]].length()}"
          upload_start = Time.now
          response = upload_resources(resource[:resourceType], resources[resource[:resourceType]])
          upload_finish = Time.now
          puts "upload time: #{upload_finish - upload_start}"
          resources[resource[:resourceType]] = [] unless !response.success?
          puts response unless response.success?
        end
        # binding.pry unless response.success?
      end
  end

  resources.each do |key, value|
    puts "uploading last batch"
    upload_start = Time.now
    response = upload_resources(key, value)
    upload_finish = Time.now
    puts "upload time: #{upload_finish - upload_start}"
    resources[key] = [] unless !response.success?
    puts response unless response.success?
  end

ensure
  definitions_file.unlink
end

def upload_devoted_resources
  resources = {}
  file_path = File.join(__dir__, 'output', '**/*.json')
  filenames =
    Dir.glob(file_path)
      .partition { |filename| filename.include? 'List' }
      .flatten
  puts "Uploading #{filenames.length} resources"
  filenames.each_with_index do |filename, index|
    resource = JSON.parse(File.read(filename), symbolize_names: true)
    resources[resource[:resourceType]] = [] unless resources.key?(resource[:resourceType])
    resources[resource[:resourceType]].push(resource)
    
    if resources[resource[:resourceType]].length() >= BATCH_SIZE
      puts "uploading batch of #{resources[resource[:resourceType]].length()} #{resource[:resourceType]} resources"
      upload_start = Time.now
      response = upload_resources(resource[:resourceType], resources[resource[:resourceType]])
      upload_finish = Time.now
      puts "upload time: #{upload_finish - upload_start}"
      resources[resource[:resourceType]] = [] unless !response.success?
      puts response unless response.success?
    end

    if index % 100 == 0
      puts index
    end
  end

  resources.each do |key, value|
    puts "uploading last batch of #{key}"
    upload_start = Time.now
    response = upload_resources(key, value)
    upload_finish = Time.now
    puts "upload time: #{upload_finish - upload_start}"
    resources[key] = [] unless !response.success?
    puts response unless response.success?
  end
end

def upload_us_core_resources
  resources = {}
  file_path = File.join(__dir__, 'us-core', '*.json')
  filenames =
    Dir.glob(file_path)
      .partition { |filename| filename.include? 'ValueSet' }
      .flatten
      .partition { |filename| filename.include? 'CodeSystem' }
      .flatten
  filenames.each do |filename|
    resource = JSON.parse(File.read(filename), symbolize_names: true)
    resources[resource[:resourceType]] = [] unless resources.key?(resource[:resourceType])
    resources[resource[:resourceType]].push(resource)
  end

  resources.each do |key, value|
    puts "uploading last batch of #{key}"
    upload_start = Time.now
    response = upload_resources(key, value)
    upload_finish = Time.now
    puts "upload time: #{upload_finish - upload_start}"
    resources[key] = [] unless !response.success?
    puts response unless response.success?
  end
end

def upload_resources(resource_type, resources)
  bundle = {
    :resourceType => "Bundle",
    :id => "bundle-transaction",
    :type => "transaction",
    :entry => [],
  }

  resources.each do |resource|
    bundle_resource = {
      :resource => resource,
      :request => {
        :method => "POST",
        :url => resource_type,
      }
    }

    bundle[:entry] << bundle_resource
  end

  HTTParty.post(
    "#{FHIR_SERVER}",
    body: bundle.to_json,
    headers: { 'Content-Type': 'application/json', 'Prefer': 'return=minimal' },
    timeout: 240
  )
end

def upload_resource(resource)
  resource_type = resource[:resourceType]
  id = resource[:id]
  begin
    HTTParty.put(
      "#{FHIR_SERVER}/#{resource_type}/#{id}",
      body: resource.to_json,
      headers: { 'Content-Type': 'application/json' }
    )
  rescue StandardError
  end
end


upload_us_core_resources
upload_conformance_resources
upload_devoted_resources
