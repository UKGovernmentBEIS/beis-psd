require "rails_helper"

RSpec.describe "Case specific information spec", :with_stubbed_opensearch, :with_stubbed_mailer do
  let(:team) { create :team }
  let(:user) { create :user, :activated, has_viewed_introduction: true, team: }
  let(:investigation) { create :allegation, creator: user }
  let(:product_1) { create :product }
  let(:product_2) { create :product }
  let(:product_3) { create :product }
  let(:product_4) { create :product }

  context "when investigation has multiple linked products" do
    before do
      InvestigationProduct.create!(investigation_id: investigation.id, product_id: product_1.id, customs_code: "ABC123", batch_number: "1", affected_units_status: "unknown")
      InvestigationProduct.create!(investigation_id: investigation.id, product_id: product_2.id, customs_code: "XYZ987", batch_number: "2", affected_units_status: "exact", number_of_affected_units: "91")
      InvestigationProduct.create!(investigation_id: investigation.id, product_id: product_3.id, customs_code: "ZZZ999", batch_number: "3", affected_units_status: "approx", number_of_affected_units: "10000")
      InvestigationProduct.create!(investigation_id: investigation.id, product_id: product_4.id, customs_code: "BBB222", batch_number: "1000", affected_units_status: "not_relevant")
    end

    it "shows all info on case specific info section of case page" do
      sign_in user
      visit investigation_path(investigation)

      expect_investigation_products_to_be_listed_with_oldest_first

      within("dl.product-0") do
        expect(page).to have_css("dt.govuk-summary-list__key", text: "Batch numbers")
        expect(page).to have_css("dd.govuk-summary-list__value", text: product_1.investigation_products.first.batch_number)

        expect(page).to have_css("dt.govuk-summary-list__key", text: "Customs codes")
        expect(page).to have_css("dd.govuk-summary-list__value", text: product_1.investigation_products.first.customs_code)

        expect(page).to have_css("dt.govuk-summary-list__key", text: "Units affected")
        expect(page).to have_css("dd.govuk-summary-list__value", text: "Unknown")
      end

      within("dl.product-1") do
        expect(page).to have_css("dt.govuk-summary-list__key", text: "Units affected")
        expect(page).to have_css("dd.govuk-summary-list__value", text: "91 Exact number")
      end

      within("dl.product-2") do
        expect(page).to have_css("dt.govuk-summary-list__key", text: "Units affected")
        expect(page).to have_css("dd.govuk-summary-list__value", text: "10000 Approximate number")
      end

      within("dl.product-3") do
        expect(page).to have_css("dt.govuk-summary-list__key", text: "Units affected")
        expect(page).to have_css("dd.govuk-summary-list__value", text: "Not relevant")
      end
    end
  end

  context "when investigation has no linked products" do
    it "shows empty case specific info section of case page" do
      sign_in user
      visit investigation_path(investigation)
      expect(page).to have_css("h4", text: "You can add this information after a product has been added to the case")
    end
  end
end

def product_titles
  all("h4.opss-secondary-text").map(&:text)
end

def expect_investigation_products_to_be_listed_with_oldest_first
  expect(product_titles).to eq([product_1.name, product_2.name, product_3.name, product_4.name])
end
