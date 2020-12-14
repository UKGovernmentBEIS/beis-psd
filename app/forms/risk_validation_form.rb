class RiskValidationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :is_risk_validated, :boolean, default: nil
  attribute :risk_validated_by, :string
  attribute :risk_validated_at, :datetime
  attribute :risk_validation_change_rationale, default: nil
  attribute :previous_risk_validated_at

  validates :is_risk_validated, inclusion: { in: [true, false], message: "Select yes if you have validated the case risk level" }
  validates :risk_validation_change_rationale, presence: true, if: -> { risk_validation_removed? }

  def risk_validation_removed?
    !previous_risk_validated_at.nil? && is_risk_validated == false
  end
end
