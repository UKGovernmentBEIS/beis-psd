class RiskAssessmentForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Serialization

  EMPTY_PROMPT_OPTION = [{ text: "", value: "" }.freeze].freeze

  attribute :investigation
  attribute :current_user

  attr_accessor :assessed_on_year, :assessed_on_month, :assessed_on_day

  attribute :assessed_on, :govuk_date
  attribute "assessed_on(1i)"
  attribute "assessed_on(2i)"
  attribute "assessed_on(3i)"

  attribute :risk_level

  attribute :assessed_by
  attribute :assessed_by_team_id
  attribute :assessed_by_business_id
  attribute :assessed_by_other

  attribute :investigation_product_ids

  attribute :old_file
  attribute :risk_assessment_file
  attribute :existing_risk_assessment_file_file_id

  attribute :details

  validates :assessed_on, presence: true
  validates :risk_level, presence: true

  validates :risk_assessment_file, presence: true, unless: -> { old_file.present? }

  validates :assessed_by, presence: true
  validate :at_least_one_product_associated

  validates :assessed_by_team_id, presence: true, if: -> { assessed_by == "another_team" }
  validates :assessed_by_business_id, presence: true, if: -> { assessed_by == "business" }
  validates :assessed_by_other, presence: true, if: -> { assessed_by == "other" }

  validates :assessed_on,
            real_date: true,
            complete_date: true,
            not_in_future: true,
            recent_date: { on_or_before: false }

  validate :date_fields_presence
  def initialize(attributes = {})
    super

    @assessed_on_year = attributes["assessed_on(1i)"]
    @assessed_on_month = attributes["assessed_on(2i)"]
    @assessed_on_day = attributes["assessed_on(3i)"]
  end

  def cache_file!
    return if risk_assessment_file.blank?

    self.risk_assessment_file = ActiveStorage::Blob.create_and_upload!(
      io: risk_assessment_file,
      filename: risk_assessment_file.original_filename,
      content_type: risk_assessment_file.content_type
    )

    self.existing_risk_assessment_file_file_id = risk_assessment_file.signed_id
  end

  def load_risk_assessment_file
    if existing_risk_assessment_file_file_id.present? && risk_assessment_file.nil?
      self.risk_assessment_file = ActiveStorage::Blob.find_signed!(existing_risk_assessment_file_file_id)
    end
  end

  def risk_levels
    {
      serious: "serious",
      high: "high",
      medium: "medium",
      low: "low",
      not_conclusive: "not_conclusive"
    }
  end

  def investigation_products
    investigation.investigation_products.map do |ip|
      {
        text: "#{ip.product.name} (#{ip.psd_ref})",
        value: ip.id,
        disable_ghost: true,
        checked: investigation_product_ids.to_a.include?(ip.id)
      }
    end
  end

  def other_teams
    EMPTY_PROMPT_OPTION.deep_dup +
      Team
        .order(:name)
        .where.not(id: current_user.team_id)
        .pluck(:name, :id).collect do |row|
          { text: row[0], value: row[1] }
        end
  end

  def businesses_select_items
    EMPTY_PROMPT_OPTION.deep_dup + investigation.businesses
      .reorder(:trading_name)
      .pluck(:trading_name, :id).map do |row|
        { text: row[0], value: row[1] }
      end
  end

  def assessed_by_business_id
    if assessed_by == "business"
      super
    end
  end

  def assessed_by_team_id
    case assessed_by
    when "my_team"
      current_user.team_id
    when "another_team"
      super
    end
  end

  def assessed_by_other
    if assessed_by == "other"
      super
    end
  end

private

  def set_date
    if @assessed_on_year.present? && @assessed_on_month.present? && @assessed_on_day.present?
      begin
        Date.new(@assessed_on_year.to_i, @assessed_on_month.to_i, @assessed_on_day.to_i)
      rescue ArgumentError
        @assessed_on = nil
      end
    else
      @assessed_on = nil
    end
  end

  def date_fields_presence
    year = @assessed_on_year
    month = @assessed_on_month
    day = @assessed_on_day

    errors.add(:assessed_on, "Date sent must include a year") if year.blank?
    errors.add(:assessed_on, "Date sent must include a month") if month.blank?
    errors.add(:assessed_on, "Date sent must include a day") if day.blank?
    Date.new(year.to_i, month.to_i, day.to_i)
  rescue ArgumentError
    errors.add(:assessed_on, "Date is invalid")
  end

  def at_least_one_product_associated
    return unless investigation_product_ids.to_a.empty?

    errors.add(:investigation_product_ids, :blank)
  end
end
