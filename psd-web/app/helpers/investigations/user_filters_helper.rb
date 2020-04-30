module Investigations::UserFiltersHelper
  def entities
    User.get_owners(except: current_user) + Team.all_with_organisation
  end

  def assigned_to(form)
    assigned_to_items = [{ key: "case_owner_is_me", value: "checked", unchecked_value: "unchecked", text: "Me" }]
    owner_teams_with_keys.each do |key, team, name|
      assigned_to_items << { key: key, value: team.id, unchecked_value: "unchecked", text: name }
    end
    assigned_to_items << { key: "case_owner_is_someone_else",
                 value: "checked",
                 unchecked_value: "unchecked",
                 text: "Other person or team",
                 conditional: { html: other_owner(form) } }
  end

  def created_by(form)
    created_by_items = [{ key: "created_by_me", value: "checked", unchecked_value: "unchecked", text: "Me" }]
    creator_teams_with_keys.each do |key, team, name|
      created_by_items << { key: key, value: team.id, unchecked_value: "unchecked", text: name }
    end
    created_by_items << { key: "created_by_someone_else",
                 value: "checked",
                 unchecked_value: "unchecked",
                 text: "Other person or team",
                 conditional: { html: other_creator(form) } }
  end

  def other_owner(form)
    render "form_components/govuk_select", key: :case_owner_is_someone_else_id, form: form,
                  items: entities.map { |e| { text: e.display_name, value: e.id } },
                  label: { text: "Name" }, is_autocomplete: true
  end

  def other_creator(form)
    render "form_components/govuk_select", key: :created_by_someone_else_id, form: form,
                  items: entities.map { |e| { text: e.display_name, value: e.id } },
                  label: { text: "Name" }, is_autocomplete: true
  end
end
