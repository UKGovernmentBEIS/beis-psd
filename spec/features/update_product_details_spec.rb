require "rails_helper"

RSpec.feature "Updating product details", :with_stubbed_mailer, :with_stubbed_opensearch, type: :feature do
  let(:user) { create(:user, :activated) }

  let(:product) do
    create(:product,
           name: "MyBrand washing machine",
           category: "Electrical appliances and equipment",
           subcategory: "washing machine",
           product_code: "MBWM01",
           batch_number: "Batches 0001 to 0231",
           webpage: "http://example.com/mybrand/washing-machines",
           description: "White with chrome buttons",
           affected_units_status: "approx",
           number_of_affected_units: 1)
  end

  scenario "Updating a product" do
    sign_in(user)

    visit "/products/#{product.id}"
    expect_to_be_on_product_page(product_id: product.id, product_name: "MyBrand washing machine")

    click_link "Edit details"

    expect_to_be_on_edit_product_page(product_id: product.id, product_name: "MyBrand washing machine")

    expect(page).to have_field("Product category", with: "Electrical appliances and equipment")
    expect(page).to have_field("Product subcategory", with: "washing machine")
    expect(page).to have_field("Product name", with: "MyBrand washing machine")
    expect(page).to have_field("Other product identifiers", text: "MBWM01")
    expect(page).to have_field("Batch number", with: "Batches 0001 to 0231")
    expect(page).to have_field("Webpage", with: "http://example.com/mybrand/washing-machines")
    expect(page).to have_field("Description of product", text: "White with chrome buttons")

    select "Kitchen / cooking accessories", from: "Product category"
    fill_in "Product subcategory", with: "dishwasher"
    fill_in "Product name", with: "MyBrand dishwasher"
    fill_in "Other product identifiers", with: "MBDW01"
    fill_in "Batch number", with: "Batches 0005 to 1023"
    fill_in "Webpage", with: "http://example.com/mybrand/dishwashers"
    fill_in "Description of product", with: "White with chrome handle"
    within_fieldset("How many units are affected?") do
      choose "Approximate number known"
      find("#approx_units").set(2)
    end

    click_button "Save product"

    expect_to_be_on_product_page(product_id: product.id, product_name: "MyBrand dishwasher")

    expect(page).to have_text "Product was successfully updated."

    expect(page).to have_summary_item(key: "Product name", value: "MyBrand dishwasher")
    expect(page).to have_summary_item(key: "Category", value: "Kitchen / cooking accessories")
    expect(page).to have_summary_item(key: "Product subcategory", value: "dishwasher")
    expect(page).to have_summary_item(key: "Other product identifiers", value: "MBDW01")
    expect(page).to have_summary_item(key: "Batch number", value: "Batches 0005 to 1023")
    expect(page).to have_summary_item(key: "Webpage", value: "http://example.com/mybrand/dishwashers")
    expect(page).to have_summary_item(key: "Description", value: "White with chrome handle")
    expect(page).to have_summary_item(key: "Units affected", value: "2")
  end
end
