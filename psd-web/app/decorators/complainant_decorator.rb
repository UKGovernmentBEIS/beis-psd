class ComplainantDecorator < ApplicationDecorator
  delegate_all

  def summary_list
    contact_details = [
      name, phone_number, email_address, other_details
    ]

    rows = [
      { key: { text: "Type" }, value: { text: complainant.complainant_type } },
    ]

    if contact_details.any?
      rows << {
        key: { text: "Contact details" },
        value: { text: h.simple_format(contact_details.join("\n")) }
      }
    end

    h.render "components/govuk_summary_list", rows: rows
  end
end
