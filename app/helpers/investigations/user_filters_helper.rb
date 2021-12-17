module Investigations::UserFiltersHelper
  def entities
    User.get_owners(except: current_user).decorate + Team.not_deleted.decorate
  end

  def created_by(form)
    render "form_components/govuk_select",
           key: :created_by_other_id,
           form: form,
           items: entities.map { |e| { text: e.display_name(viewer: current_user), value: e.id, selected: form.object.teams_with_access_other_id == e.id } },
           label: { text: "Person or team name" },
           is_autocomplete: true,
           attributes: { "data-opss-clear-on-reset" => "autocomplete" }
  end

  def other_owner(form)
    render "form_components/govuk_select",
           key: :case_owner_is_someone_else_id,
           form: form,
           items: entities.map { |e| { text: e.display_name(viewer: current_user), value: e.id } },
           label: { text: "Person or team name" },
           is_autocomplete: true,
           attributes: { "data-opss-clear-on-reset" => "autocomplete" }
  end

  def other_teams(form)
    other_teams = Team.not_deleted.where.not(id: current_user.team)

    render "form_components/govuk_select",
           key: :teams_with_access_other_id,
           form: form,
           items: other_teams.map { |e| { text: e.display_name(viewer: current_user), value: e.id, selected: form.object.teams_with_access_other_id == e.id } },
           label: { text: "Team name" },
           is_autocomplete: true,
           attributes: { "data-opss-clear-on-reset" => "autocomplete" }
  end

  def other_creator(form)
    render "form_components/govuk_select",
           key: :created_by_other,
           form: form,
           items: entities.map { |e| { text: e.display_name(viewer: current_user), value: e.id, selected: form.object.created_by.id == e.id } },
           label: { text: "Name" },
           is_autocomplete: true,
           attributes: { "data-opss-clear-on-reset" => "autocomplete" }
  end
end
