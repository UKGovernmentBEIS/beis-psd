module InvestigationsHelper
  include SearchHelper

  def search_for_investigations(page_size = Investigation.count)
    query  = ElasticsearchQuery.new(@search.q, filter_params, @search.sorting_params)
    result = Investigation.full_search(query)
    result.paginate(page: params[:page], per_page: page_size)
  end

  def set_search_params
    params_to_save = params.dup
    params_to_save.delete(:sort_by) if params[:sort_by] == SearchParams::RELEVANT
    @search = SearchParams.new(query_params)
    session[:previous_search_params] = params_to_save
  end

  def filter_params
    filters = {}
    filters.merge!(get_type_filter)
    filters.merge!(merged_must_filters) { |_key, current_filters, new_filters| current_filters + new_filters }
  end

  def merged_must_filters
    must_filters = { must: [get_status_filter, { bool: get_creator_filter }, { bool: get_owner_filter }] }

    if params[:coronavirus_related_only] == "yes"
      must_filters[:must] << { term: { coronavirus_related: true } }
    end

    must_filters
  end

  def get_status_filter
    return nil if params[:status_open] == params[:status_closed]

    status = if params[:status_open] == "checked"
               { is_closed: false }
             else
               { is_closed: true }
             end
    { term: status }
  end

  def get_type_filter
    return {} if params[:allegation] == "unchecked" && params[:enquiry] == "unchecked" && params[:project] == "unchecked"

    types = []
    types << "Investigation::Allegation" if params[:allegation] == "checked"
    types << "Investigation::Enquiry" if params[:enquiry] == "checked"
    types << "Investigation::Project" if params[:project] == "checked"
    type = { type: types }
    { must: [{ terms: type }] }
  end

  def get_owner_filter
    return { should: [], must_not: [] } if no_owner_boxes_checked
    return { should: [], must_not: compute_excluded_terms } if owner_filter_exclusive

    { should: compute_included_terms, must_not: [] }
  end

  def no_owner_boxes_checked
    no_people_boxes_checked = params[:case_owner_is_me] == "unchecked" && params[:case_owner_is_someone_else] == "unchecked"
    no_team_boxes_checked = owner_teams_with_keys.all? { |key, _t, _n| query_params[key].blank? }
    no_people_boxes_checked && no_team_boxes_checked
  end

  def owner_filter_exclusive
    params[:case_owner_is_someone_else] == "checked" && params[:case_owner_is_someone_else_id].blank?
  end

  def compute_excluded_terms
    # After consultation with designers we chose to ignore teams who are not selected in blacklisting
    excluded_owners = []
    excluded_owners << current_user.id if params[:case_owner_is_me] == "unchecked"
    format_owner_terms(excluded_owners)
  end

  def compute_included_terms
    # If 'Me' is not checked, but one of current users teams is selected, we don't exclude current user from it
    owners = checked_team_owners
    owners.concat(someone_else_owners)
    owners << current_user.id if params[:case_owner_is_me] == "checked"
    format_owner_terms(owners.uniq)
  end

  def checked_team_owners
    owners = []
    owner_teams_with_keys.each do |key, team, _n|
      owners.concat(user_ids_from_team(team)) if query_params[key] != "unchecked"
    end
    owners
  end

  def someone_else_owners
    return [] unless params[:case_owner_is_someone_else] == "checked"

    team = Team.find_by(id: params[:case_owner_is_someone_else_id])
    team.present? ? user_ids_from_team(team) : [params[:case_owner_is_someone_else_id]]
  end

  def format_owner_terms(owner_array)
    owner_array.map do |a|
      { term: { owner_id: a } }
    end
  end

  def get_creator_filter
    return { should: [], must_not: [] } if no_created_by_boxes_checked
    return { should: [], must_not: compute_excluded_created_by_terms } if creator_filter_exclusive

    { should: compute_included_created_by_terms, must_not: [] }
  end

  def no_created_by_boxes_checked
    no_created_by_people_boxes_checked = params[:created_by_me] == "unchecked" && params[:created_by_someone_else] == "unchecked"
    no_created_by_team_boxes_checked = creator_teams_with_keys.all? { |key, _t, _n| query_params[key].blank? }
    no_created_by_people_boxes_checked && no_created_by_team_boxes_checked
  end

  def creator_filter_exclusive
    params[:created_by_someone_else] == "checked" && params[:created_by_someone_else_id].blank?
  end

  def compute_excluded_created_by_terms
    # After consultation with designers we chose to ignore teams who are not selected in blacklisting
    excluded_creators = []
    excluded_creators << current_user.id if params[:created_by_me] == "unchecked"
    format_creator_terms(excluded_creators)
  end

  def compute_included_created_by_terms
    # If 'Me' is not checked, but one of current users teams is selected, we don't exclude current user from it
    creators = checked_team_creators
    creators.concat(someone_else_creators)
    creators << current_user.id if params[:created_by_me] == "checked"
    format_creator_terms(creators.uniq)
  end

  def checked_team_creators
    creators = []
    creator_teams_with_keys.each do |key, team, _n|
      creators.concat(user_ids_from_team(team)) if query_params[key] != "unchecked"
    end
    creators
  end

  def someone_else_creators
    return [] unless params[:created_by_someone_else] == "checked"

    team = Team.find_by(id: params[:created_by_someone_else_id])
    team.present? ? user_ids_from_team(team) : [params[:created_by_someone_else_id]]
  end

  def format_creator_terms(creator_array)
    creator_array.map do |a|
      { term: { creator_id: a } }
    end
  end

  def creator_teams_with_keys
    current_user.teams.map.with_index do |team, index|
      # key, team, name
      [
        "created_by_team_#{index}".to_sym,
        team,
        current_user.teams.count > 1 ? team.name : "My team"
      ]
    end
  end

  def query_params
    set_default_status_filter
    set_default_type_filter
    set_default_owner_filter
    set_default_creator_filter
    params.permit(:q, :status_open, :status_closed, :page, :allegation, :enquiry, :project, :case_owner_is_me, :case_owner_is_someone_else, :case_owner_is_someone_else_id, :sort_by, :created_by_me, :created_by_me, :created_by_someone_else, :created_by_someone_else_id, :coronavirus_related_only,
                  owner_teams_with_keys.map { |key, _t, _n| key }, creator_teams_with_keys.map { |key, _t, _n| key })
  end

  def export_params
    query_params.except(:page)
  end

  def set_default_status_filter
    params[:status_open] = "checked" if params[:status_open].blank?
  end

  def set_default_owner_filter
    params[:case_owner_is_me] = "unchecked" if params[:case_owner_is_me].blank?
    params[:case_owner_is_team_0] = "unchecked" if params[:case_owner_is_team_0].blank?
    params[:case_owner_is_someone_else] = "unchecked" if params[:case_owner_is_someone_else].blank?
  end

  def set_default_creator_filter
    params[:created_by_me] = "unchecked" if params[:created_by_me].blank?
    params[:created_by_someone_else] = "unchecked" if params[:created_by_someone_else].blank?
  end

  def set_default_type_filter
    params[:allegation] = "unchecked" if params[:allegation].blank?
    params[:enquiry] = "unchecked" if params[:enquiry].blank?
    params[:project] = "unchecked" if params[:project].blank?
  end

  def build_breadcrumb_structure
    {
        items: [
            {
                text: "Cases",
                href: investigations_path(previous_search_params)
            },
            {
                text: @investigation.pretty_description
            }
        ]
    }
  end

  def owner_teams_with_keys
    current_user.teams.map.with_index do |team, index|
      # key, team, name
      [
        "case_owner_is_team_#{index}".to_sym,
        team,
        current_user.teams.count > 1 ? team.name : "My team"
      ]
    end
  end

  def user_ids_from_team(team)
    [team.id] + team.users.map(&:id)
  end

  def suggested_previous_owners
    all_past_owners = @investigation.past_owners + @investigation.past_teams
    return [] if all_past_owners.empty? || all_past_owners == [current_user]

    all_past_owners || []
  end
end
