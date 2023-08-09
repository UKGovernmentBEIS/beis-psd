class InvestigationSerializer < ActiveModel::Serializer
  attributes :type, :owner_id, :creator_id, :hazard_type,
             :description, :product_category, :is_closed, :updated_at, :created_at,
             :pretty_id, :hazard_description, :non_compliant_reason,
             :complainant_reference, :risk_level, :title

  has_many :businesses, serializer: BusinessSerializer
  has_many :products, serializer: ProductSerializer
  # has_many :users, serializer: UserSerializer
  # has_many :teams_with_access, serializer: TeamAccessSerializer
  has_many :collaborations, serializer: CollaborationSerializer

end
