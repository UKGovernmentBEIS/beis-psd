class InvestigationDecorator < ApplicationDecorator
  include FormattedDescription
  include ActionView::Helpers::OutputSafetyHelper
  delegate_all
  decorates_associations :complainant, :documents_attachments, :creator_user, :owner_user, :owner_team, :activities, :risk_assessments

  PRODUCT_DISPLAY_LIMIT = 6

  def title
    user_title
  end

  def display_product_summary_list?
    products.any?
  end

  def risk_assessment_risk_levels
    risk_assessments.collect(&:risk_level_description).uniq
  end

  def product_summary_list
    products_details = [products.count, "product".pluralize(products.count), "added"].join(" ")
    rows = [
      category.present? ? { key: { text: "Category" }, value: { text: category } } : nil,
      {
        key: { text: "Product details" },
        value: { text: products_details },
        actions: { items: [href: h.investigation_products_path(object), visually_hidden_text: "product details", text: "View"] }
      },
    ]
    rows.compact!
    h.govukSummaryList rows:, classes: "govuk-summary-list--no-border"
  end

  def risk_level_set?
    object.risk_level.present? || object.custom_risk_level.present?
  end

  def risk_level_description
    if object.risk_level.present? && !object.other?
      I18n.t(".investigations.risk_level.show.levels.#{object.risk_level}")
    elsif object.custom_risk_level.present?
      object.custom_risk_level
    else
      "Not set"
    end
  end

  def details_summary_list
    action = h.tag.span("Case #{status}", class: "opss-tag opss-tag--risk3")
    h.tag.div class: "govuk-summary-list__row" do
      list = []
      if object.is_private?
        list << h.tag.dt("Allegation restricted", class: "govuk-summary-list__key")
      else
        list << h.tag.dt(h.link_to(title, h.investigation_path(object), class: 'govuk-link--no-visited-state'), class: "govuk-summary-list__key")
        list << h.tag.dd(object.pretty_id, class: "govuk-summary-list__value")
        list << h.tag.dd(object.owner_team&.name || "&ndash;".html_safe, class: "govuk-summary-list__value")
      end
      list << h.tag.dd(action, class: "govuk-summary-list__actions")
      safe_join(list)
    end
  end

  def source_details_summary_list(view_protected_details: false)
    contact_details = view_protected_details ? contact_details_list : h.tag.p("")
    contact_details << h.tag.p(I18n.t("case.protected_details", data_type: "#{object.case_type} contact details"), class: "govuk-body-s govuk-!-margin-bottom-1 opss-secondary-text opss-text-align-right")

    rows = [
      should_display_date_received? ? { key: { text: "Received date" }, value: { text: date_received.to_formatted_s(:govuk) } } : nil,
      should_display_received_by? ? { key: { text: "Received by" }, value: { text: received_type.upcase_first } } : nil,
      { key: { text: "Source type" }, value: { text: complainant.complainant_type } },
      { key: { text: "Contact details" }, value: { text: contact_details } }
    ]

    rows.compact!

    h.govukSummaryList rows:, classes: "govuk-summary-list govuk-summary-list--no-border opss-summary-list-mixed opss-summary-list-mixed--narrow-dt"
  end

  def contact_details_list
    h.tag.ul(class: "govuk-list govuk-list--bullet govuk-list--spaced") do
      lis = []
      lis << h.tag.li(complainant.name) if complainant.name.present?
      lis << h.tag.li("Telephone: #{complainant.phone_number}") if complainant.phone_number.present?
      lis << h.tag.li("Email: ".html_safe + h.mail_to(complainant.email_address, class: "govuk-link govuk-link--no-visited-state")) if complainant.email_address.present?
      lis << h.tag.li(complainant.other_details) if complainant.other_details.present?
      safe_join(lis)
    end
  end

  def pretty_description
    "#{case_type.upcase_first}: #{pretty_id}"
  end

  def created_by
    return if creator_user.nil?

    "#{creator_user.full_name} - #{creator_user.team.name}"
  end

  def products_list
    product_count = products.count
    limit         = PRODUCT_DISPLAY_LIMIT

    limit += 1 if product_count - PRODUCT_DISPLAY_LIMIT == 1

    products_remaining_count = products.offset(limit).count

    h.tag.ul(class: "govuk-list") do
      h.concat(h.render(products.limit(limit)))
      if product_count > limit
        h.concat(h.link_to("View #{products_remaining_count} more products...", h.investigation_products_path(object)))
      end
    end
  end

  def owner_display_name_for(viewer:)
    return "No case owner" unless investigation.owner

    owner.owner_short_name(viewer:)
  end

  def generic_attachment_partial(viewing_user)
    return "documents/restricted_generic_document_card" unless Pundit.policy!(viewing_user, object).view_protected_details?(user: viewing_user)

    "documents/generic_document_card"
  end

  def owner
    object.owner&.decorate
  end

  def status
    is_closed? ? "Closed" : "Open"
  end

  def visibility_status
    is_private? ? "restricted" : "unrestricted"
  end

  def visibility_action
    is_private? ? "unrestrict" : "restrict"
  end

private

  def category
    @category ||= \
      if categories.size == 1
        h.simple_format(categories.first.downcase.upcase_first, class: "govuk-body")
      else
        h.tag.ul(class: "govuk-list") do
          lis = categories.map { |cat| h.tag.li(cat.downcase.upcase_first) }
          lis.join.html_safe
        end
      end
  end

  def should_display_date_received?
    false
  end

  def should_display_received_by?
    false
  end
end
