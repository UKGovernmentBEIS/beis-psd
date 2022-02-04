require "rails_helper"

RSpec.feature "Searching cases", :with_opensearch, :with_stubbed_mailer, type: :feature do
  let(:user) { create :user, :activated, has_viewed_introduction: true }

  let(:product) do
    create(:product,
           name: "MyBrand washing machine",
           category: "kitchen appliances",
           product_code: "W2020-10/1")
  end
  let!(:investigation) { create(:allegation, products: [product]) }

  let(:mobile_phone) do
    create(:product,
           name: "T12 mobile phone",
           category: "consumer electronics")
  end

  let(:mobilz_phont) do
    create(:product,
           name: "T12 mobilz phont",
           category: "consumer electronics")
  end

  let(:thirteenproduct) do
    create(:product,
           name: "thirteenproduct",
           category: "consumer electronics")
  end

  let(:eeirteenproduct) do
    create(:product,
           name: "eeirteenproduct",
           category: "consumer electronics")
  end

  let!(:mobile_phone_investigation) { create(:allegation, products: [mobile_phone]) }
  let!(:mobilz_phont_investigation) { create(:allegation, products: [mobilz_phont]) }
  let!(:thirteenproduct_investigation) { create(:allegation, products: [thirteenproduct]) }
  let!(:eeirteenproduct_investigation) { create(:allegation, products: [eeirteenproduct]) }

  before do
    # Import products syncronously into Opensearch
    Investigation.__elasticsearch__.import refresh: :wait_for
  end

  scenario "searching for a case using a keyword from a product name" do
    sign_in(user)
    visit "/cases"

    fill_in "Keywords", with: "MyBrand"
    click_button "Search"

    expect_to_be_on_cases_search_results_page

    expect(page).to have_content "1 case matching keyword(s) MyBrand, using the current filters, was found."

    expect(page).to have_text(investigation.pretty_id)

    # Full product name should be shown
    expect(page).to have_text("MyBrand washing machine")

    # The part of the product name which matches the search term should be highlighted
    expect(page).to have_selector("em", text: "MyBrand")
  end

  scenario "searching for a case using a close-matching product name keyword" do
    sign_in(user)
    visit "/cases"

    fill_in "Keywords", with: "MyBran"
    click_button "Search"

    expect_to_be_on_cases_search_results_page

    expect(page).to have_content "1 case matching keyword(s) MyBran, using the current filters, was found."

    expect(page).to have_text(investigation.pretty_id)
    expect(page).to have_text("MyBrand washing machine")
  end

  scenario "searching for a case using an exact matching product code" do
    sign_in(user)
    visit "/cases"

    fill_in "Keywords", with: "W2020-10/1"
    click_button "Search"

    expect_to_be_on_cases_search_results_page

    expect(page).to have_content "1 case matching keyword(s) W2020-10/1, using the current filters, was found."

    expect(page).to have_text(investigation.pretty_id)
    expect(page).to have_text("MyBrand washing machine")
  end

  scenario "searching for a case using a query string that includes trailing or leading whitespaces" do
    sign_in(user)
    visit "/cases"

    fill_in "Keywords", with: " W2020-10/1   "
    click_button "Search"

    expect_to_be_on_cases_search_results_page

    expect(page).to have_content "1 case matching keyword(s) W2020-10/1, using the current filters, was found."

    expect(page).to have_text(investigation.pretty_id)
    expect(page).to have_text("MyBrand washing machine")
  end

  scenario "searching for cases using multiple keywords" do
    pending 'this will be fixed once we re-add fuzzy "or" matching on'
    sign_in(user)
    visit "/cases"

    fill_in "Keywords", with: "mybrand mobile phone"
    click_button "Search"

    expect_to_be_on_cases_search_results_page

    expect(page).to have_content "2 cases matching keyword(s) mybrand mobile phone, using the current filters, was found."

    # Both cases returned even though neither matches ALL the keywords
    expect(page).to have_text(investigation.pretty_id)
    expect(page).to have_text("MyBrand washing machine")

    expect(page).to have_text(mobile_phone_investigation.pretty_id)
    expect(page).to have_text("T12 mobile phone")
  end

  context "with fuzzy matching" do
    it "does not allow any edits for words less than 6 letters long" do
      sign_in(user)
      visit "/cases"

      fill_in "Keywords", with: "phone"
      click_button "Search"

      expect_to_be_on_cases_search_results_page

      expect(page).to have_content "1 case matching keyword(s) phone, using the current filters, was found."

      expect(page).to have_text(mobile_phone_investigation.pretty_id)
      expect(page).to have_text("T12 mobile phone")

      expect(page).not_to have_text(mobilz_phont_investigation.pretty_id)
      expect(page).not_to have_text("T12 mobilz phont")
    end

    it "allows 1 edit for words more than 6 letters but less than 13 long" do
      sign_in(user)
      visit "/cases"

      fill_in "Keywords", with: "mobile"
      click_button "Search"

      expect_to_be_on_cases_search_results_page

      expect(page).to have_content "2 cases matching keyword(s) mobile, using the current filters, were found."

      expect(page).to have_text(mobile_phone_investigation.pretty_id)
      expect(page).to have_text("T12 mobile phone")

      expect(page).to have_text(mobilz_phont_investigation.pretty_id)
      expect(page).to have_text("T12 mobilz phont")
    end

    it "does not allow 2 edits for words more than 6 letters but less than 13 long" do
      sign_in(user)
      visit "/cases"

      fill_in "Keywords", with: "mobiee"
      click_button "Search"

      expect_to_be_on_cases_search_results_page

      expect(page).to have_content "1 case matching keyword(s) mobiee, using the current filters, was found."

      expect(page).to have_text(mobile_phone_investigation.pretty_id)
      expect(page).to have_text("T12 mobile phone")

      expect(page).not_to have_text(mobilz_phont_investigation.pretty_id)
      expect(page).not_to have_text("T12 mobilz phont")
    end

    it "allows 2 edits for words more than 12 long" do
      sign_in(user)
      visit "/cases"

      fill_in "Keywords", with: "thirteenproduct"
      click_button "Search"

      expect_to_be_on_cases_search_results_page

      expect(page).to have_content "2 cases matching keyword(s) thirteenproduct, using the current filters, were found."

      expect(page).to have_text(thirteenproduct_investigation.pretty_id)
      expect(page).to have_text("thirteenproduct")

      expect(page).to have_text(eeirteenproduct_investigation.pretty_id)
      expect(page).to have_text("eeirteenproduct")
    end

    it "does not allow 3 edits for words more than 12 long" do
      sign_in(user)
      visit "/cases"

      fill_in "Keywords", with: "thirteenproduce"
      click_button "Search"

      expect_to_be_on_cases_search_results_page

      expect(page).to have_content "1 case matching keyword(s) thirteenproduce, using the current filters, was found."

      expect(page).to have_text(thirteenproduct_investigation.pretty_id)
      expect(page).to have_text("thirteenproduct")

      expect(page).not_to have_text(eeirteenproduct_investigation.pretty_id)
      expect(page).not_to have_text("eeirteenproduct")
    end

    context "no search term is used" do

      it "shows all results if no word is searched for" do
        sign_in(user)
        visit "/cases"

        fill_in "Keywords", with: ""
        click_button "Search"

        expect(page).to have_content "5 cases using the current filters, were found."

        expect(page).to have_text(thirteenproduct_investigation.pretty_id)
        expect(page).to have_text("thirteenproduct")

        expect(page).to have_text(eeirteenproduct_investigation.pretty_id)
        expect(page).to have_text("eeirteenproduct")

        expect(page).to have_text(mobile_phone_investigation.pretty_id)
        expect(page).to have_text("T12 mobile phone")

        expect(page).to have_text(mobilz_phont_investigation.pretty_id)
        expect(page).to have_text("T12 mobilz phont")

        expect(page).to have_text(investigation.pretty_id)
        expect(page).to have_text("MyBrand washing machine")
      end

      context "over 10k cases exist" do
        before do
          allow(Investigation).to receive(:count) {10001}
          sign_in(user)
        end

        it "shows total number of cases" do
          visit "/cases"
          expect(page).to have_content "10001 cases using the current filters, were found."
        end
      end
    end
  end
end
