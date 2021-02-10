class AuditActivity::AccidentOrIncident::AccidentOrIncidentUpdated < AuditActivity::Base
  def self.from(*)
    raise "Deprecated - use UpdateAccidentOrIncident.call instead"
  end

  def self.build_metadata(accident_or_incident)
    updates = accident_or_incident.previous_changes.slice(
      :date,
      :is_date_known,
      :product_id,
      :severity,
      :severity_other,
      :usage,
      :additional_info,
    )

    {
      accident_or_incident_id: accident_or_incident.id,
      updates: updates,
      event_type: accident_or_incident.type
    }
  end

  def title(*)
    metadata["event_type"]
  end

  def subtitle_slug
    "Updated"
  end

  def date_changed?
    new_date?
  end

  def new_date?
    updates["date"]&.second || updates["is_date_known"]&.second
  end

  def new_date
    return unless new_date?
    return updates["date"]&.second if updates["date"]&.second

    if updates["is_date_known"]&.second == "yes"
      updates["date"]&.first
    else
      "Unknown"
    end
  end

  def product_changed?
    new_product_id
  end

  def new_product_id
    updates["product_id"]&.second
  end

  def severity_changed?
    new_severity
  end

  def new_severity
    updates["severity"]&.second
  end

  def new_severity_other
    updates["severity_other"]&.second
  end

  def usage_changed?
    new_usage
  end

  def new_usage
    updates["usage"]&.second
  end

  def additional_info_changed?
    new_additional_info
  end

  def new_additional_info
    updates["additional_info"]&.second
  end

private

  def updates
    metadata["updates"]
  end

  # Do not send investigation_updated mail when risk assessment updated. This
  # overrides inherited functionality in the Activity model :(
  def notify_relevant_users; end
end
