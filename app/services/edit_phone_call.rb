class EditPhoneCall
  include Interactor
  include EntitiesToNotify

  delegate :activity, :correspondence, :user, :transcript, :correspondence_date, :correspondent_name, :overview, :details, :phone_number, to: :context

  def call
    context.fail!(error: "No user supplied") unless user.is_a?(User)
    context.fail!(error: "No phone supplied") unless correspondence.is_a?(Correspondence::PhoneCall)

    Correspondence.transaction do
      context.correspondence.update!(
        transcript: transcript,
        correspondence_date: correspondence_date,
        phone_number: phone_number,
        correspondent_name: correspondent_name,
        overview: overview,
        details: details
      )

      context.activity = AuditActivity::Correspondence::PhoneCallUpdated.create!(
        source: UserSource.new(user: user),
        investigation: correspondence.investigation,
        correspondence: correspondence,
        metadata: AuditActivity::Correspondence::PhoneCallUpdated.build_metadata(correspondence)
      )

      send_notification_email
    end
  end

private

  def investigation
    correspondence.investigation
  end

  def send_notification_email
    entities_to_notify.each do |entity|
      NotifyMailer.investigation_updated(
        investigation.pretty_id,
        entity.name,
        entity.email,
        email_update_text,
        activity.email_subject_text
      ).deliver_later
    end
  end

  def email_update_text
    "Phone call details added to the #{investigation.case_type.upcase_first} by #{activity.source.show}."
  end
end
