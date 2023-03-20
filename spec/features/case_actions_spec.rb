require "rails_helper"

RSpec.feature "Case actions", :with_stubbed_opensearch, :with_stubbed_antivirus, :with_stubbed_mailer, type: :feature do
  let(:user) { create :user, :opss_user, :activated, has_viewed_introduction: true }
  let(:investigation_1) { create :allegation, creator: user }
  let(:washing_machine) { create :product_washing_machine }
  let(:investigation_2) { create :allegation, products: [washing_machine], creator: user }
  let(:investigation_3) { create :allegation, read_only_teams: [user.team] }
  let(:investigation_4) { create :allegation, :with_business, :with_products, :with_document, creator: user }

  before do
    sign_in user
  end

  scenario "without a product added to the case" do
    visit investigation_path(investigation_1)
    expect_to_be_on_case_page(case_id: investigation_1.pretty_id)
    expect(page).to have_css(".govuk-warning-text")
    expect(page).to have_text("A product has not been added to this case.")

    within("#page-content section dl.govuk-summary-list") do
      expect(page).to have_text("Product (0 added)")
      expect(page).to have_text("Business (0 added)")
      expect(page).to have_text("Image (0 added)")
      expect(page).to have_text("Accident / Incident (0 added)")
      expect(page).to have_text("Corrective action (0 added)")
      expect(page).to have_text("Risk assessment (0 added)")
      expect(page).to have_text("Correspondence (0 added)")
      expect(page).to have_text("Test result (0 added)")
      expect(page).to have_text("Other supporting information (0 added)")
    end
  end

  scenario "with a product added to the case" do
    visit investigation_path(investigation_2)
    expect_to_be_on_case_page(case_id: investigation_2.pretty_id)
    expect(page).not_to have_css(".govuk-warning-text")

    within("#page-content section dl.govuk-summary-list") do
      expect(page).to have_text("Product (1 added)")
      expect(page).to have_text("Business (0 added)")
      expect(page).to have_text("Image (0 added)")
      expect(page).to have_text("Accident / Incident (0 added)")
      expect(page).to have_text("Corrective action (0 added)")
      expect(page).to have_text("Risk assessment (0 added)")
      expect(page).to have_text("Correspondence (0 added)")
      expect(page).to have_text("Test result (0 added)")
      expect(page).to have_text("Other supporting information (0 added)")
    end
  end

  scenario "where the user can edit the case" do
    visit investigation_path(investigation_1)
    within("#page-content section dl.govuk-summary-list") do
      expect(page).to have_link("Add a product", href: new_investigation_product_path(investigation_1))
      expect(page).to have_link("Add a business", href: new_investigation_business_path(investigation_1))
      expect(page).to have_link("Add an image", href: new_investigation_document_path(investigation_1))
      expect(page).to have_link("Add an accident or incident", href: new_investigation_accident_or_incidents_type_path(investigation_1))
      expect(page).to have_link("Add a corrective action", href: new_investigation_corrective_action_path(investigation_1))
      expect(page).to have_link("Add a risk assessment", href: new_investigation_risk_assessment_path(investigation_1))
      expect(page).to have_link("Add a correspondence", href: new_investigation_correspondence_path(investigation_1))
      expect(page).to have_link("Add a test result", href: new_investigation_test_result_path(investigation_1))
      expect(page).to have_link("Add a document or attachment", href: new_investigation_document_path(investigation_1))
      expect(page).to have_link("Add a comment", href: new_investigation_activity_comment_path(investigation_1))
    end
  end

  scenario "where the user can not edit the case" do
    visit investigation_path(investigation_3)
    within("#page-content section dl.govuk-summary-list") do
      expect(page).not_to have_link("Add a product")
      expect(page).not_to have_link("Add a business")
      expect(page).not_to have_link("Add an image")
      expect(page).not_to have_link("Add an accident or incident")
      expect(page).not_to have_link("Add a corrective action")
      expect(page).not_to have_link("Add a risk assessment")
      expect(page).not_to have_link("Add a correspondence")
      expect(page).not_to have_link("Add a test result")
      expect(page).not_to have_link("Add a document or attachment")
      expect(page).to have_link("Add a comment", href: new_investigation_activity_comment_path(investigation_3))
    end
  end

  scenario "with some information added to the case" do
    visit investigation_path(investigation_4)
    within("#page-content section dl.govuk-summary-list") do
      expect(page).to have_text("Product (1 added)")
      expect(page).to have_text("Business (1 added)")
      expect(page).to have_text("Image (0 added)")
      expect(page).to have_text("Accident / Incident (0 added)")
      expect(page).to have_text("Corrective action (0 added)")
      expect(page).to have_text("Risk assessment (0 added)")
      expect(page).to have_text("Correspondence (0 added)")
      expect(page).to have_text("Test result (0 added)")
      expect(page).to have_text("Other supporting information (1 added)")
    end
  end
end
