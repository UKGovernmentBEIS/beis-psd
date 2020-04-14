class HealthController < ApplicationController
  skip_before_action :authenticate_user!, :authorize_user, :has_accepted_declaration, :has_viewed_introduction

  http_basic_authenticate_with name: ENV.fetch("HEALTH_CHECK_USERNAME", "health"), password: ENV.fetch("HEALTH_CHECK_PASSWORD", "check")

  def show
    # Check redis services
    Redis.new(Rails.application.config_for(:redis_session)).info
    Redis.new(Rails.application.config_for(:redis_store)).info

    # Check database connection
    ActiveRecord::Migrator.current_version

    # Check Elasticsearch cluster health
    raise "Elasticsearch is down" if Elasticsearch::Client.new(Rails.application.config_for(:elasticsearch)).cluster.health[:status] == "red"

    # Check Sidekiq queue length (in time) is within an acceptable limit
    raise "Sidekiq queue latency is above 30 seconds" if Sidekiq::Queue.new(ENV["SIDEKIQ_QUEUE"] || "psd").latency > 30

    # Check investigations being present in the database
    raise "Database does not contain any investigation" if Investigation.count.zero?

    render plain: "OK"
  end
end
