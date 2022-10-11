require "rails_helper"

RSpec.feature "Adding a product", :with_stubbed_mailer, :with_stubbed_opensearch, :with_product_form_helper do
  let(:user)       { create(:user, :activated) }
  let(:attributes) do
    attributes_for(:product_iphone, authenticity: Product.authenticities.keys.without("missing", "unsure").sample)
  end

  scenario "Adding a product" do
    sign_in user
    visit "/products/new"

    fill_in "Barcode number (GTIN, EAN or UPC)", with: "invalid"

    click_button "Save"

    # Expected validation errors
    expect(page).to have_error_messages
    errors_list = page.find(".govuk-error-summary__list").all("li")
    expect(errors_list[0].text).to eq "Category cannot be blank"
    expect(errors_list[1].text).to eq "Subcategory cannot be blank"
    expect(errors_list[2].text).to eq "You must state whether the product is a counterfeit"
    expect(errors_list[3].text).to eq "Select yes if the product has UKCA, UKNI or CE marking"
    expect(errors_list[4].text).to eq "Name cannot be blank"
    expect(errors_list[5].text).to eq "Select yes if the product was placed on the market before 1 January 2021"
    expect(errors_list[6].text).to eq "Enter a valid barcode number"

    select attributes[:category], from: "Product category"

    fill_in "Product subcategory",               with: attributes[:subcategory]
    fill_in "Manufacturer's brand name",         with: attributes[:brand]
    fill_in "Product name",                      with: attributes[:name]
    fill_in "Barcode number (GTIN, EAN or UPC)", with: attributes[:barcode]
    fill_in "Other product identifiers",         with: attributes[:product_code]
    fill_in "Webpage",                           with: attributes[:webpage]

    within_fieldset("Was the product placed on the market before 1 January 2021?") do
      choose when_placed_on_market_answer(attributes[:when_placed_on_market])
    end

    within_fieldset("Is the product counterfeit?") do
      choose counterfeit_answer(attributes[:authenticity])
    end

    within_fieldset("Does the product have UKCA, UKNI, or CE marking?") do
      page.find("input[value='#{attributes[:has_markings]}']").choose
    end

    within_fieldset("Select product marking") do
      attributes[:markings].each { |marking| check(marking) } if attributes[:has_markings] == "markings_yes"
    end

    select attributes[:country_of_origin], from: "Country of origin"

    fill_in "Description of product", with: attributes[:description]

    click_on "Save"

    expect(page).to have_current_path("/products")
    expect(page).not_to have_error_messages
    expect(page).to have_selector("h1", text: "Product record created")

    click_on "View the product record"

    expected_markings = case attributes[:has_markings]
                        when "markings_yes" then attributes[:markings].join(", ")
                        when "markings_no" then "None"
                        when "markings_unknown" then "Unknown"
                        end

    expect(page).to have_summary_item(key: "Product brand",             value: attributes[:brand])
    expect(page).to have_summary_item(key: "Product name",              value: attributes[:name])
    expect(page).to have_summary_item(key: "Category",                  value: attributes[:category])
    expect(page).to have_summary_item(key: "Product subcategory",       value: attributes[:subcategory])
    expect(page).to have_summary_item(key: "Product authenticity",      value: I18n.t(attributes[:authenticity], scope: Product.model_name.i18n_key))
    expect(page).to have_summary_item(key: "Product marking",           value: expected_markings)
    expect(page).to have_summary_item(key: "Barcode number",            value: attributes[:gin13])
    expect(page).to have_summary_item(key: "Other product identifiers", value: attributes[:product_code])
    expect(page).to have_summary_item(key: "Webpage",                   value: attributes[:webpage])
    expect(page).to have_summary_item(key: "Country of origin",         value: attributes[:country])
    expect(page).to have_summary_item(key: "Description",               value: attributes[:description])
    expect(page).to have_summary_item(key: "When placed on market",     value: I18n.t(attributes[:when_placed_on_market], scope: Product.model_name.i18n_key))
  end
end
