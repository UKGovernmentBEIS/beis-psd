class AuditActivity::Investigation::RiskLevelUpdated < AuditActivity::Investigation::Base
  I18N_SCOPE = "audit_activity.investigation.risk_level_updated".freeze
  SUBTITLE_SLUG = "Risk level changed".freeze

  def self.build_metadata(investigation, update_verb)
    updated_values = investigation.previous_changes.slice(:risk_level)
    {
      updates: updated_values,
      update_verb:
    }
  end

  def title(_user)
    I18n.t(".title.#{metadata['update_verb']}", level: new_risk_level&.downcase, scope: I18N_SCOPE)
  end

private

  def subtitle_slug
    SUBTITLE_SLUG
  end

  def new_risk_level
    return "" if metadata["update_verb"] == "removed"

    new_risk_level_value = metadata["updates"]["risk_level"]&.second
    I18n.t(".investigations.risk_level.show.levels.#{new_risk_level_value}")
  end
end
