# frozen_string_literal: true

class SearchParams
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Serialization

  SORT_BY_OPTIONS = [
    BLANK    = "blank",
    NEWEST   = "newest",
    OLDEST   = "oldest",
    RECENT   = "recent",
    RELEVANT = "relevant"
  ].freeze

  attribute :allegation
  attribute :case_owner_is_me, :boolean
  alias_method :case_owner_is_me?, :case_owner_is_me
  attribute :case_owner_is_my_team, :boolean
  alias_method :case_owner_is_my_team?, :case_owner_is_my_team
  attribute :case_owner_is_someone_else, :boolean
  alias_method :case_owner_is_someone_else?, :case_owner_is_someone_else
  attribute :case_owner_is_someone_else_id
  attribute :created_by_me, :boolean
  alias_method :created_by_me?, :created_by_me
  attribute :created_by_someone_else, :boolean
  alias_method :created_by_someone_else?, :created_by_someone_else
  attribute :created_by_someone_else_ids, default: []
  attribute :direction
  attribute :enquiry
  attribute :project
  attribute :q
  attribute :status
  attribute :status_open, :boolean, default: true
  alias_method :status_open?, :status_open
  attribute :status_closed, :boolean
  attribute :coronavirus_related_only, :boolean
  alias_method :coronavirus_related_only?, :coronavirus_related_only
  attribute :serious_and_high_risk_level_only, :boolean
  alias_method :serious_and_high_risk_level_only?, :serious_and_high_risk_level_only
  attribute :sort_by, default: BLANK
  attribute :page, :integer
  attribute :created_by, :created_by_search_params, default: CreatedBySearchFormFields.new
  attribute :teams_with_access, :teams_with_access_search_params, default: TeamsWithAccessSearchFormFields.new
  attribute :hazard_type

  def owner_filter_exclusive?
    case_owner_is_someone_else? && case_owner_is_someone_else_id.blank?
  end

  def created_by_filter_exclusive?
    created_by.someone_else? && created_by.id.blank?
  end

  def no_owner_boxes_checked?
    return false if case_owner_is_me?
    return false if case_owner_is_my_team?

    !case_owner_is_someone_else?
  end

  def no_created_by_checked?
    !created_by.me? && !created_by.my_team? && !created_by.someone_else?
  end

  def teams_with_access_ids
    @teams_with_access_ids ||= teams_with_access.ids
  end

  def filter_teams_with_access?
    teams_with_access_ids.any?
  end

  def filter_status?
    status_open != status_closed
  end

  def is_closed?
    !status_open?
  end

  def sort_by_option
    if sort_by == BLANK || !sort_by.present?
      return RELEVANT if q.present?
      return RECENT
    end
    sort_by
  end

  def sorting_params
    case sort_by_option
    when NEWEST
      { created_at: "desc" }
    when OLDEST
      { updated_at: "asc" }
    when RECENT
      { updated_at: "desc" }
    else
      { updated_at: "desc" }
    end
  end

  def sort_by_items
    [
      { text: "", value: BLANK, unchecked_value: "unchecked" },
      { text: "Recent updates", value: RECENT, unchecked_value: "unchecked" },
      { text: "Oldest updates", value: OLDEST, unchecked_value: "unchecked" },
      { text: "Newest cases", value: NEWEST, unchecked_value: "unchecked" }
    ]
  end
end
