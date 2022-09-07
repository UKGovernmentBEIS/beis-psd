require "rails_helper"

RSpec.feature "Updating product details", :with_stubbed_mailer, :with_stubbed_opensearch, type: :feature do
  let(:user) { create(:user, :activated) }

  let(:product) do
    create(:product,
           name: "MyBrand washing machine",
           category: "Electrical appliances and equipment",
           subcategory: "washing machine",
           product_code: "MBWM01",
           webpage: "http://example.com/mybrand/washing-machines",
           description: "White with chrome buttons")
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
    expect(page).to have_field("Webpage", with: "http://example.com/mybrand/washing-machines")
    expect(page).to have_field("Description of product", text: "White with chrome buttons")

    select "Kitchen / cooking accessories", from: "Product category"
    fill_in "Product subcategory", with: "dishwasher"
    fill_in "Product name", with: "MyBrand dishwasher"
    fill_in "Other product identifiers", with: "MBDW01"
    fill_in "Webpage", with: "http://example.com/mybrand/dishwashers"
    fill_in "Description of product", with: "White with chrome handle"

    click_button "Save"

    expect_to_be_on_product_page(product_id: product.id, product_name: "MyBrand dishwasher")

    expect(page).to have_text "Product was successfully updated."

    expect(page).to have_summary_item(key: "PSD ref", value: "#{product.psd_ref} - The PSD reference for this product record")
    expect(page).to have_summary_item(key: "Product name", value: "MyBrand dishwasher")
    expect(page).to have_summary_item(key: "Category", value: "Kitchen / cooking accessories")
    expect(page).to have_summary_item(key: "Product subcategory", value: "dishwasher")
    expect(page).to have_summary_item(key: "Other product identifiers", value: "MBDW01")
    expect(page).to have_summary_item(key: "Webpage", value: "http://example.com/mybrand/dishwashers")
    expect(page).to have_summary_item(key: "Description", value: "White with chrome handle")
  end
end
