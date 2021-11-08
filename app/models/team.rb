class Team < ApplicationRecord
  include Deletable
  include TeamCollaboratorInterface

  belongs_to :organisation
  has_many :users, dependent: :restrict_with_exception

  has_many :collaborations, dependent: :destroy, as: :collaborator
  has_many :collaboration_accesses, class_name: "Collaboration::Access", as: :collaborator

  has_many :owner_collaborations, class_name: "Collaboration::Access::OwnerTeam", as: :collaborator

  has_many :roles, dependent: :destroy, as: :entity

  validates :name, presence: true
  validates :country, presence: true

  redacted_export_with :id, :country, :created_at, :deleted_at, :name, :organisation_id, :updated_at

  def display_name(*)
    name
  end

  def self.get_visible_teams(user)
    team_names = Rails.application.config.team_names["organisations"]["opss"]
    return where(name: team_names) if user.is_opss?

    where(name: team_names.first)
  end

  def users_alphabetically_with_users_without_names_first
    users.not_deleted.order(Arel.sql("name IS NOT NULL"), :name)
  end
end
