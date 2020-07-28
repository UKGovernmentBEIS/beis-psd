class UpdateCorrectiveActionForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations::Callbacks
  include SanitizationHelper
  include CorrectiveActionValidation
  include DateConcern

  attribute :summary
  attribute :legislation
  attribute :measure_type
  attribute :duration
  attribute :geographic_scope
  attribute :details
  attribute :date_decided
  attribute :date_decided_day
  attribute :date_decided_month
  attribute :date_decided_year
  attribute :file, :file_form

  delegate :description, to: :file, prefix: true

  def initialize(corrective_action_params)
    super
    trim_line_endings(:summary, :details)
    initialize_date(:date_decided, true)
    set_dates_from_params(corrective_action_params)
  end

  def attributes
    {
      summary: summary,
      legislation: legislation,
      measure_type: measure_type,
      duration: duration,
      geographic_scope: geographic_scope,
      details: details,
      date_decided: date_decided,
      documents: [file.file]
    }
  end

  def [](key)
    public_send(key)
  end

  def []=(key, value)
    public_send("#{key}=", value)
  end

private

  attr_accessor :corrective_action, :corrective_action_params

  def related_file_attachment_validation
    if related_file && file.file.nil?
      errors.add(:base, :file_missing, message: "Provide a related file or select no")
    end
  end
end
