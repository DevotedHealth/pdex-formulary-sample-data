require 'json'
require 'pry'

FHIR_SERVER_BASE = "https://fhir.dev.devoted.com/fhir"

# First output the *List*.json, these are the CoveragePlan profile instances
puts "working on input directory: output..."
FileUtils.mkdir_p("export/")
outfile = "CoveragePlan.ndjson"
ndouts = []
ndouts << {
    "type" => "List",
    "url" => "#{FHIR_SERVER_BASE}/resources/#{outfile}"
}
puts "writing to export/#{outfile}"
    o = File.open("export/#{outfile}","w")
    Dir.glob("output/*.json") do |jsonfile|
        puts "working on: #{jsonfile}..."
        s = File.read(jsonfile)
        h = JSON.parse(s)
        o.puts(JSON.generate(h))
    end
    o.close
    # Next iterate through the directories, each one contains the MedicationKnowledge profile instances for a single plan
    Dir.glob("output/*/") do |plandir|
        outfile = "FormularyDrug_#{File.basename(plandir)}.ndjson"
        puts "writing to #{outfile}"
        url = "#{FHIR_SERVER_BASE}/resources/#{outfile}"
        ndouts << {
            "type" => "MedicationKnowledge",
            "url" => url
        }
        o = File.open("export/#{outfile}","w")
        Dir.glob("#{plandir}/*.json") do |jsonfile|
            s = File.read(jsonfile)
            h = JSON.parse(s)
            o.puts(JSON.generate(h))
        end
        o.close
    end

    # Add provider directory resources
    # HACK! TODO figure out best approach to manage dependencies across libraries
    ndouts.concat([{
      "type": "Organization",
      "url": "https://fhir.dev.devoted.com/fhir/resources/Organization.ndjson"
    },
    {
      "type": "Practitioner",
      "url": "https://fhir.dev.devoted.com/fhir/resources/Practitioner.ndjson"
    },
    {
      "type": "Location",
      "url": "https://fhir.dev.devoted.com/fhir/resources/Location.ndjson"
    },
    {
      "type": "HealthcareService",
      "url": "https://fhir.dev.devoted.com/fhir/resources/HealthcareService.ndjson"
    },
    {
      "type": "Endpoint",
      "url": "https://fhir.dev.devoted.com/fhir/resources/Endpoint.ndjson"
    },
    {
      "type": "InsurancePlan",
      "url": "https://fhir.dev.devoted.com/fhir/resources/InsurancePlan.ndjson"
    },
    {
      "type": "PractitionerRole",
      "url": "https://fhir.dev.devoted.com/fhir/resources/PractitionerRole.ndjson"
    },
    {
      "type": "OrganizationAffiliation",
      "url": "https://fhir.dev.devoted.com/fhir/resources/OrganizationAffiliation.ndjson"
    }])

    output = {
        "transactionTime" => Time.now.strftime("%d/%m/%Y %H:%M"),
        "request" => "#{FHIR_SERVER_BASE}/fhir/$export",
        "requiresAccessToken" => false,
        "output" => ndouts,
        "error" => { "type" => "OperationOutcome",
                    "url" =>  "#{FHIR_SERVER_BASE}/resources/err_file_1.ndjson"}
    }
    export = File.open("export/export.json","w")
    export.write(JSON.pretty_generate(output))
    puts "Files written to /export"