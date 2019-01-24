class AuditActivity::Investigation::AddQuestion < AuditActivity::Investigation::Add
  def self.from(investigation)
    super(investigation, self.build_title(investigation), self.build_body(investigation))
  end

  def self.build_title(investigation)
    "Enquiry logged: #{investigation.title}"
  end

  def self.build_body(investigation)
    body = "**Enquiry details**<br>"
    body += "<br>Attachment: **#{self.sanitize_text investigation.documents.first.filename}**<br>" if investigation.documents.attached?
    body += "<br>#{self.sanitize_text investigation.description}" if investigation.description.present?
    body += self.build_reporter_details(investigation.reporter) if investigation.reporter.present?
    body
  end
end
