class AuditActivity::AccidentOrIncident::AccidentOrIncidentUpdatedDecorator < ActivityDecorator
  def new_date
    return activity.new_date if activity.new_date == "Unknown"

    Date.parse(activity.new_date).to_s(:govuk)
  end

  def new_severity
    return activity.new_severity_other if activity.new_severity.inquiry.other?

    I18n.t(".accident_or_incident.severity.#{activity.new_severity}")
  end

  def new_usage
    I18n.t(".accident_or_incident.usage.#{activity.new_usage}")
  end

  def type
    activity.metadata["type"]
  end

  def additional_info
    activity.metadata["additional_info"]
  end

  def product_updated?
    metadata.dig("updates", "product_id", 1)
  end
end
