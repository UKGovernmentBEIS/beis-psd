require "rails_helper"

RSpec.feature "Investigation listing", :with_elasticsearch, :with_stubbed_mailer, :with_stubbed_keycloak_config do
  let(:user)                                   { create :user, :activated }
  let!(:projects)                              { create_list :project, 18, updated_at: 4.days.ago }
  let!(:investigation_last_updated_3_days_ago) { create(:allegation, updated_at: 3.days.ago, description: Faker::Hipster.paragraph).decorate }
  let!(:investigation_last_updated_2_days_ago) { create(:allegation, updated_at: 2.days.ago, description: Faker::Hipster.paragraph).decorate }
  let!(:investigation_last_updated_1_days_ago) { create(:allegation, updated_at: 1.day.ago,  description: Faker::Hipster.paragraph).decorate }

  before { allow(AuditActivity::Investigation::Base).to receive(:from) }

  let(:pagination_link_params) do
    {
      allegation: :unchecked,
      assigned_to_me: :unchecked,
      assigned_to_someone_else: :unchecked,
      created_by_me: :unchecked,
      created_by_someone_else: :unchecked,
      enquiry: :unchecked,
      page: 2,
      project: :unchecked,
      status_open: :checked
    }
  end


  scenario "lists cases correctly sorted" do
    # it is necessary to re-import and wait for the indexing to be done.
    Investigation.import refresh: :wait_for

    sign_in(as_user: user)
    visit investigations_path

    expect(page).
      to have_css(".govuk-grid-row.psd-case-card:nth-child(1) .govuk-grid-column-one-half span.govuk-caption-m", text: investigation_last_updated_1_days_ago.pretty_description)
    expect(page).
      to have_css(".govuk-grid-row.psd-case-card:nth-child(2) .govuk-grid-column-one-half span.govuk-caption-m", text: investigation_last_updated_2_days_ago.pretty_description)
    expect(page).
      to have_css(".govuk-grid-row.psd-case-card:nth-child(3) .govuk-grid-column-one-half span.govuk-caption-m", text: investigation_last_updated_3_days_ago.pretty_description)

    expect(page).to have_css(".pagination em.current", text: 1)
    expect(page).to have_link("2",      href: /#{Regexp.escape(investigations_path(pagination_link_params))}/)
    expect(page).to have_link("Next →", href: /#{Regexp.escape(investigations_path(pagination_link_params))}/)

    fill_in "Keywords", with: investigation_last_updated_3_days_ago.object.description.split(" ")[0..2].join(" ")
    click_on "Apply filters"

    expect(page).
      to have_css(".govuk-grid-row.psd-case-card:nth-child(1) .govuk-grid-column-one-half span.govuk-caption-m", text: investigation_last_updated_3_days_ago.pretty_description)
    expect(page.find("input[name='sort_by'][value='#{SearchParams::RELEVANT}']")).to be_checked
  end
end
