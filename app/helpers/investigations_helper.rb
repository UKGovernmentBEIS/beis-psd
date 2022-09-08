module InvestigationsHelper
  include InvestigationSearchHelper

  def search_for_investigations(page_size = Investigation.count, user = current_user)
    result = Investigation.full_search(search_query(user))
    result.page(page_number).per(page_size)
  end

  def query_params
    params.permit(
      :q,
      :case_status,
      :case_type,
      :page,
      :case_owner,
      :sort_by,
      :sort_dir,
      :priority,
      :teams_with_access,
      :case_owner_is_someone_else_id,
      :teams_with_access_other_id,
      :created_by,
      :created_by_other_id,
      :page_name
    )
  end

  def export_params
    query_params.except(:page, :sort_by, :page_name)
  end

  def build_breadcrumb_structure
    {
      items: [
        {
          text: "Cases",
          href: investigations_path
        },
        {
          text: @investigation.pretty_description
        }
      ]
    }
  end

  def safety_and_compliance_rows(investigation)
    rows = []

    reported_reason = investigation.reported_reason ? investigation.reported_reason.to_sym : :not_provided

    rows << {
      key: { text: t(:reported_as, scope: "investigations.overview.safety_and_compliance") },
      value: { text: simple_format(t(reported_reason.to_sym, scope: "investigations.overview.safety_and_compliance")) },
    }

    if investigation.unsafe_and_non_compliant? || investigation.unsafe?
      rows << {
        key: { text: t(:primary_hazard, scope: "investigations.overview.safety_and_compliance") },
        value: { text: simple_format(investigation.hazard_type) },
      }

      rows << {
        key: { text: t(:description, scope: "investigations.overview.safety_and_compliance") },
        value: { text: simple_format(investigation.hazard_description) },
      }
    end

    if investigation.unsafe_and_non_compliant? || investigation.non_compliant?
      rows << {
        key: { text: t(:key, scope: "investigations.overview.compliance") },
        value: { text: simple_format(investigation.non_compliant_reason) },
      }
    end

    rows
  end

  def case_rows(investigation, user, team_list_html)
    rows = [
      {
        key: { text: "Case name" },
        value: { text: investigation.title },
        actions: case_name_actions(investigation, user)
      },
      {
        key: { text: investigation.case_type.capitalize },
        value: {
          text: investigation.pretty_id,
          secondary_text: { html: '<span class="govuk-!-font-size-16 govuk-!-padding-left-2 opss-secondary-text"><span class="govuk-visually-hidden"> - </span>Case number</span>' }
        },
        actions: {}
      },
      {
        key: { text: "Reference" },
        value: {
          text: investigation.complainant_reference,
          secondary_text: { text: "Trading standards reference" }
        },
        actions: reference_actions(investigation, user)
      },
      {
        key: { text: "Summary" },
        value: {
          text: investigation.description
        },
        actions: summary_actions(investigation, user)
      },
      {
        key: { text: "Status" },
        value: status_value(investigation),
        actions: status_actions(investigation, user)
      },
      {
        key: { text: "Last updated" },
        value: {
          text: "#{time_ago_in_words(@investigation.updated_at)} ago"
        }
      },
      {
        key: { text: "Created by" },
        value: {
          text: investigation.created_by
        }
      },
      {
        key: { text: "Case owner" },
        value: {
          text: investigation_owner(investigation)
        },
        actions: case_owner_actions(investigation, user)
      },
      {
        key: { text: "Teams added" },
        value: {
          html: team_list_html
        },
        actions: case_teams_actions(investigation)
      },
      {
        key: { text: "Case restriction" },
        value: {
          html: case_restriction_value(investigation)
        },
        actions: case_restriction_actions(investigation, user)
      },
      {
        key: { text: "Case risk level" },
        value: {
          html: case_risk_level_value(investigation)
        },
        actions: risk_level_actions(investigation, user)
      },
      {
        key: { text: t("investigations.risk_validation.page_title") },
        value: { text: risk_validated_value(investigation) },
        actions: risk_validation_actions(investigation, user)
      }
    ]

    if investigation.coronavirus_related
      rows << {
        key: { text: "COVID-19" },
        value: {
          html: '<span class="opss-tag opss-tag--covid opss-tag--lrg">COVID-19 related</span>'.html_safe
        },
        actions: {
          items: []
        }
      }
    end

    rows
  end

  def search_result_statement(search_terms, number_of_results)
    search_result_values = search_result_values(search_terms, number_of_results)

    render "investigations/search_result", word: search_result_values[:word], number_of_cases_in_english: search_result_values[:number_of_cases_in_english], search_terms:
  end

  def risk_validated_link_text(investigation)
    investigation.risk_validated_by ? "Change" : t("investigations.risk_validation.validate")
  end

  def form_serialisation_option
    options = {}
    options[:except] = :sort_by if params[:sort_by] == SortByHelper::SORT_BY_RELEVANT

    options
  end

  def options_for_notifying_country(countries, notifying_country_form)
    countries.map do |country|
      text = country[0]
      option = { text:, value: country[1] }
      option[:selected] = true if notifying_country_form.country == text
      option
    end
  end

private

  def search_result_values(_search_terms, number_of_results)
    word = number_of_results == 1 ? "was" : "were"

    number_of_cases_in_english = "#{number_of_results} #{'case'.pluralize(number_of_results)}"

    {
      number_of_cases_in_english:,
      word:
    }
  end

  def case_name_actions(investigation, user)
    return {} unless policy(investigation).update?(user:)

    {
      items: [
        href: edit_investigation_case_names_path(investigation.pretty_id),
        text: "Edit",
        visuallyHiddenText: " the case name"
      ]
    }
  end

  def reference_actions(investigation, user)
    return {} unless policy(investigation).update?(user:)

    {
      items: [
        href: edit_investigation_reference_numbers_path(investigation.pretty_id),
        text: "Edit",
        visuallyHiddenText: " the reference number"
      ]
    }
  end

  def summary_actions(investigation, user)
    return {} unless policy(investigation).update?(user:)

    {
      items: [
        href: edit_investigation_summary_path(investigation.pretty_id),
        text: "Edit",
        visuallyHiddenText: " the summary"
      ]
    }
  end

  def status_actions(investigation, user)
    return {} unless policy(investigation).change_owner_or_status?(user:)

    status_path = investigation.is_closed ? reopen_investigation_status_path(investigation) : close_investigation_status_path(investigation)
    status_link_text = investigation.is_closed? ? "Re-open" : "Close"

    {
      items: [
        href: status_path,
        text: status_link_text,
        visuallyHiddenText: " the case"
      ]
    }
  end

  def case_owner_actions(investigation, user)
    return {} unless policy(investigation).change_owner_or_status?(user:)

    {
      items: [
        href: new_investigation_ownership_path(investigation),
        text: "Change",
        visuallyHiddenText: " the case owner"
      ]
    }
  end

  def case_teams_actions(investigation)
    return {} unless policy(investigation).manage_collaborators?

    {
      items: [
        href: investigation_collaborators_path(investigation),
        text: "Change",
        visuallyHiddenText: " the teams added"
      ]
    }
  end

  def case_restriction_actions(investigation, user)
    return {} unless policy(investigation).change_owner_or_status?(user:)

    {
      items: [
        href: investigation_visibility_path(investigation),
        text: "Change",
        visuallyHiddenText: " the case restriction"
      ]
    }
  end

  def risk_level_actions(investigation, user)
    return {} unless policy(investigation).update?(user:)

    {
      items: [
        href: investigation_risk_level_path(investigation),
        text: "Change",
        visuallyHiddenText: " the risk level"
      ]
    }
  end

  def risk_validation_actions(investigation, user)
    return {} unless policy(Investigation).risk_level_validation? && investigation.teams_with_access.include?(user.team)

    {
      items: [
        href: edit_investigation_risk_validations_path(investigation.pretty_id),
        text: risk_validated_link_text(investigation)
      ]
    }
  end

  def status_value(investigation)
    if investigation.is_closed?
      {
        html: '<span class="opss-tag opss-tag--risk3">Case closed</span>'.html_safe,
        secondary_text: { text: investigation.date_closed.to_s(:govuk) }
      }
    else
      {
        text: "Open"
      }
    end
  end

  def case_restriction_value(investigation)
    investigation.is_private ? '<span class="opss-tag opss-tag--risk2 opss-tag--lrg"><span class="govuk-visually-hidden">This case is </span>Restricted'.html_safe : "Unrestricted"
  end

  def case_risk_level_value(investigation)
    investigation.risk_level == "serious" ? '<span class="opss-tag opss-tag--risk1 opss-tag--lrg">Serious risk</span>'.html_safe : investigation.risk_level_description
  end

  def risk_validated_value(investigation)
    if investigation.risk_validated_by
      t("investigations.risk_validation.validated_status", risk_validated_by: investigation.risk_validated_by, risk_validated_at: investigation.risk_validated_at.strftime("%d %B %Y"))
    else
      t("investigations.risk_validation.not_validated")
    end
  end
end
