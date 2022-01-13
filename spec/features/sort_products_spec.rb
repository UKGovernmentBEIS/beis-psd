require "rails_helper"

RSpec.feature "Product sorting", :with_opensearch, :with_stubbed_mailer, type: :feature do
  let(:organisation)          { create(:organisation) }
  let(:user)                  { create(:user, :activated, organisation: organisation, has_viewed_introduction: true) }

  let!(:chemical_investigation)              { create(:allegation, hazard_type: "Chemical") }
  let!(:fire_investigation)                  { create(:allegation, hazard_type: "Fire") }
  let!(:drowning_investigation)              { create(:allegation, hazard_type: "Drowning") }

  let!(:fire_product_1)   { create(:product, name: "Hot product", investigations: [fire_investigation]) }
  let!(:fire_product_2)   { create(:product, name: "Very hot product", investigations: [fire_investigation]) }
  let!(:chemical_product) { create(:product, name: "Some lab stuff", investigations: [chemical_investigation]) }
  let!(:drowning_product) { create(:product, name: "Dangerous life vest", investigations: [drowning_investigation]) }

  before do
    Investigation.import refresh: :wait_for
    Product.import refresh: :wait_for
    sign_in(user)
    visit products_path
  end

  scenario "no filters applied sorts by Newly added" do
    expect(page).to have_css("form dl.opss-dl-select dd", text: "Active: Newly added")

    expect(page).to have_css("#item-0", text: drowning_product.name)
    expect(page).to have_css("#item-1", text: chemical_product.name)
    expect(page).to have_css("#item-2", text: fire_product_2.name)
    expect(page).to have_css("#item-3", text: fire_product_1.name)
  end

  scenario "selecting Name A–Z sorts ascending by name" do
    within "form dl.govuk-list.opss-dl-select" do
      click_on "Name A–Z"
    end
    expect(page).to have_current_path(/sort_by=name/, ignore_query: false)
    expect(page).to have_current_path(/sort_dir=asc/, ignore_query: false)
    expect(page).to have_css("form dl.opss-dl-select dd", text: "Active: Name A–Z")

    expect(page).to have_css("#item-0", text: drowning_product.name)
    expect(page).to have_css("#item-1", text: fire_product_1.name)
    expect(page).to have_css("#item-2", text: chemical_product.name)
    expect(page).to have_css("#item-3", text: fire_product_2.name)
  end

  scenario "selecting Name Z–A sorts descending by name" do
    within "form dl.govuk-list.opss-dl-select" do
      click_on "Name Z–A"
    end
    expect(page).to have_current_path(/sort_by=name/, ignore_query: false)
    expect(page).to have_current_path(/sort_dir=desc/, ignore_query: false)
    expect(page).to have_css("form dl.opss-dl-select dd", text: "Active: Name Z–A")

    expect(page).to have_css("#item-0", text: fire_product_2.name)
    expect(page).to have_css("#item-1", text: chemical_product.name)
    expect(page).to have_css("#item-2", text: fire_product_1.name)
    expect(page).to have_css("#item-3", text: drowning_product.name)
  end

  scenario "selected sort order is persisted when filtering by hazard type" do
    within "form dl.govuk-list.opss-dl-select" do
      click_on "Name A–Z"
    end

    select "Fire", from: "Hazard type"
    click_button "Apply"

    expect(page).to have_current_path(/sort_by=name/, ignore_query: false)
    expect(page).to have_css("form dl.govuk-list.opss-dl-select dd", text: "Active: Name A–Z")
  end

  scenario "filtering by keyword sorts by Relevance by default" do
    fill_in "Keywords search", with: "Dangerous"
    click_button "Apply"

    expect(page).to have_css("form dl.govuk-list.opss-dl-select dd", text: "Active: Relevance")

    select "Fire", from: "Hazard type"
    click_button "Apply"

    expect(page).to have_current_path(/sort_by=relevant/, ignore_query: false)
    expect(page).to have_css("form dl.govuk-list.opss-dl-select dd", text: "Active: Relevance")
  end

  scenario "filtering by keyword persists a selected sort order" do
    within "form dl.govuk-list.opss-dl-select" do
      click_on "Name A–Z"
    end

    fill_in "Keywords search", with: "Dangerous"
    click_button "Apply"

    expect(page).to have_current_path(/sort_by=name/, ignore_query: false)
    expect(page).to have_css("form dl.govuk-list.opss-dl-select dd", text: "Active: Name")
  end
end
