class ChangeNotificationProductSafetyComplianceDetailsForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Serialization

  attribute :unsafe, :boolean
  attribute :noncompliant, :boolean
  attribute :primary_hazard, :string
  attribute :primary_hazard_description, :string
  attribute :noncompliance_description, :string
  attribute :add_reference_number, :boolean
  attribute :reference_number, :string
  attribute :current_user

  validate :at_least_one_of_unsafe_or_noncompliant
  validates :primary_hazard, :primary_hazard_description, presence: true, if: -> { unsafe }
  validates :noncompliance_description, presence: true, if: -> { noncompliant }
  validates :add_reference_number, inclusion: [true, false]
  validates :reference_number, presence: true, if: -> { add_reference_number }
  validates :primary_hazard_description, :noncompliance_description, length: { maximum: 10_000 }

  def at_least_one_of_unsafe_or_noncompliant
    errors.add(:unsafe, :blank) if unsafe.nil? && noncompliant.nil?
  end
end
