require_relative "lib/report_portal/version"

Gem::Specification.new do |spec|
  spec.name        = "report_portal"
  spec.version     = ReportPortal::VERSION
  spec.authors     = ["Office for Product Safety and Standards"]
  spec.email       = ["opss.enquiries@businessandtrade.gov.uk"]
  spec.homepage    = "https://github.com/OfficeForProductSafetyAndStandards/product-safety-database"
  spec.summary     = "OSU Support Portal"
  spec.description = "Support portal for OSU support teams to administer PSD."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org.
  # Set a fake URL here since we're not publishing this engine as a gem.
  spec.metadata["allowed_push_host"] = "https://report.product-safety-database.service.gov.uk"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/OfficeForProductSafetyAndStandards/product-safety-database"
  spec.metadata["changelog_uri"] = "https://github.com/OfficeForProductSafetyAndStandards/product-safety-database/blob/main/support_portal/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  # This should be kept in sync with the Ruby version used by the main app
  spec.required_ruby_version = ">= 3.3.4"

  spec.add_runtime_dependency "devise", "~> 4.9"
  spec.add_runtime_dependency "govuk-components", "~> 5.0"
  spec.add_runtime_dependency "govuk_design_system_formbuilder", "~> 5.0"
  spec.add_runtime_dependency "rails", ">= 7.1.3.2"
end
