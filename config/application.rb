require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "sprockets/railtie"
require "rails/test_unit/railtie"
require_relative "../lib/formatters/asim_formatter"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ProductSafetyDatabase
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
    config.eager_load_paths << Rails.root.join("presenters")
    config.autoload_paths << Rails.root.join("app/forms/concerns")
    config.autoload_paths << Rails.root.join("app/decorators/concerns")
    config.autoload_paths << Rails.root.join("app/services/concerns")

    config.sidekiq_queue = ENV.fetch("SIDEKIQ_QUEUE", "psd")
    config.active_job.queue_adapter = :sidekiq
    config.action_mailer.deliver_later_queue_name = "#{config.sidekiq_queue}-mailers"

    # This changes Rails timezone, but keeps ActiveRecord in UTC
    config.time_zone = "Europe/London"

    # Set the request timeout in seconds. The default set by Slowpoke is 15 seconds.
    # Use a longer timeout on development environments to allow for asset compilation.
    # config.slowpoke.timeout = Rails.env.production? ? 15 : 180

    config.exceptions_app = routes

    # Enable ASIM logging if ENABLE_ASIM_LOGGER is set to 'true'
    if ENV["ENABLE_ASIM_LOGGER"] == "true"
      config.lograge.enabled = true
      config.lograge.formatter = Formatters::AsimFormatter.new
      config.logger = ActiveSupport::TaggedLogging.new(Logger.new($stdout))
      config.log_tags = JsonTaggedLogger::LogTagsConfig.generate(
        :request_id,
        :remote_ip,
        JsonTaggedLogger::TagFromSession.get(:user_id),
        :user_agent,
      )
    else
      # normal development logging configuration
      config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new($stdout))
    end

    config.email_whitelist_enabled = ENV.fetch("EMAIL_WHITELIST_ENABLED", "true") == "true"
    config.notify_api_key = ENV.fetch("NOTIFY_API_KEY", "")

    config.antivirus_url = ENV.fetch("ANTIVIRUS_URL", "http://localhost:3006/safe")

    config.secondary_authentication_enabled = ENV.fetch("TWO_FACTOR_AUTHENTICATION_ENABLED", "true") == "true"
    config.whitelisted_2fa_code = ENV["WHITELISTED_2FA_CODE"]
    config.vcap_application = ENV["VCAP_APPLICATION"]
    config.two_factor_attempts = 10

    config.active_storage.resolve_model_to_route = :rails_storage_proxy
    config.active_record.yaml_column_permitted_classes = [Time]

    # vips 8.6+ is the minimum required version to use vips as an variant
    # processor
    # Because GOV.UK PaaS is currently tied to Ubuntu 18, there is no apt
    # package available for this, so we need to use mini_magick for now
    config.active_storage.variant_processor = :mini_magick

    # Avoid sassc-rails errors when compressing CSS.
    # See https://github.com/alphagov/govuk-frontend/issues/1350
    config.assets.css_compressor = nil
    config.sass.style = :compressed
  end
end
