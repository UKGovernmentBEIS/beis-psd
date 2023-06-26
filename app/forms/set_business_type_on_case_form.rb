class SetBusinessTypeOnCaseForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Serialization

  attribute :type
  attribute :online_marketplace_id
  attribute :other_marketplace_name

  BUSINESS_TYPES = %w[
    retailer online_seller online_marketplace manufacturer exporter importer fulfillment_house distributor
  ].freeze

  validates_inclusion_of :type, in: BUSINESS_TYPES
  validates :online_marketplace_id, presence: true, if: -> { is_approved_online_marketplace? }

  def set_params_on_session(session)
    session[:business_type] = type
    if is_approved_online_marketplace?
      session[:online_marketplace_id] = online_marketplace_id
    elsif is_other_online_marketplace?
      session[:other_marketplace_name] = other_marketplace_name
    end
  end

private

  def is_approved_online_marketplace?
    type == "online_marketplace" && other_marketplace_name.blank?
  end

  def is_other_online_marketplace?
    type == "online_marketplace" && other_marketplace_name.present?
  end
end
