# frozen_string_literal: true

require 'pry'
require_relative 'lib/formulary/config'
require_relative 'lib/formulary/drug_list_generator'
require_relative 'lib/formulary/qhp_drug_repo'
require_relative 'lib/formulary/qhp_importer'
require_relative 'lib/formulary/qhp_plan_repo'

config = Formulary::Config
drug_repo = Formulary::QHPDrugRepo
plan_repo = Formulary::QHPPlanRepo

Formulary::QHPImporter
  .new(config.plan_urls, plan_repo)
  .import
Formulary::QHPImporter
  .new(config.drug_urls, drug_repo)
  .import

plan_repo.all.each do |plan|
  puts "Loading #{plan.id}"
  start = Time.now
  Formulary::DrugListGenerator.new(plan).generate
  finish = Time.now
  puts "Finished in #{finish - start} seconds"
end
