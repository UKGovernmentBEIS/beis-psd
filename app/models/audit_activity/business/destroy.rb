class AuditActivity::Business::Destroy < AuditActivity::Base
  def self.build_metadata(business, reason)
    { reason: reason, business: business.attributes }
  end

  def self.from(_business, _investigation)
    raise "Deprecated - use RemoveBusinessFromCase.call instead"
  end

  def migrate_to_metadata
    match = title.match(/Removed: (?<tradding_name>.*)/)
    self.metadata = { business: { trading_name: match["tradding_name"] } }
    save!
  end

private

  def subtitle_slug
    "Business removed"
  end

  def notify_relevant_users; end
end
