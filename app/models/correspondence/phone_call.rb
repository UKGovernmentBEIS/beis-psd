class Correspondence::PhoneCall < Correspondence
  include DateConcern

  date_attribute :correspondence_date

  has_one_attached :transcript

  def validate_transcript_and_content(file_blob)
    if file_blob.nil? && (overview.empty? || details.empty?)
      errors.add(:base, "Please provide either a transcript or complete the summary and notes fields")
    end
  end
end
