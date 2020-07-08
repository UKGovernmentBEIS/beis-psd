class AuditActivity::Investigation::RiskLevelUpdated < AuditActivity::Investigation::Base
  I18N_SCOPE = "audit_activity.investigation.risk_level_updated".freeze
  SUBTITLE_SLUG = "Risk level changed".freeze

  def self.from(*)
    raise "Deprecated - use .create_for! instead"
  end

  def self.create_for!(investigation, update_verb:, source:)
    create!(
      source: source,
      investigation: investigation,
      metadata: build_metadata(investigation, update_verb)
    )
  end

  private_class_method def self.build_metadata(investigation, update_verb)
    updated_values = investigation.previous_changes.slice(:risk_level, :custom_risk_level)
    {
      updates: updated_values,
      update_verb: update_verb
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
    if investigation.risk_level.present?
      metadata["updates"]["risk_level"]&.second
    elsif investigation.custom_risk_level.present?
      metadata["updates"]["custom_risk_level"]&.second
    end
  end

  # Do not send investigation_updated mail. This is handled by the ChangeCaseRiskLevel service
  def notify_relevant_users; end
end
