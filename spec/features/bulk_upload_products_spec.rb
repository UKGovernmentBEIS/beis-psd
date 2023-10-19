require "rails_helper"

RSpec.feature "Bulk upload products", :with_stubbed_mailer do
  let(:user) { create(:user, :opss_user, :activated, has_viewed_introduction: true, roles: %w[product_bulk_uploader]) }

  before do
    sign_in(user)
  end

  scenario "Attempting to add unsafe products" do
    visit "/products/bulk-upload/triage"

    expect(page).to have_content("How would you describe the products in terms of their compliance and safety?")

    choose "Products are unsafe"
    click_button "Continue"

    expect(page).to have_content("You can’t upload multiple unsafe products")
  end

  scenario "Attempting to add a mix of unsafe and non-compliant products" do
    visit "/products/bulk-upload/triage"

    expect(page).to have_content("How would you describe the products in terms of their compliance and safety?")

    choose "Mix of non-compliant and unsafe products"
    click_button "Continue"

    expect(page).to have_content("You can’t upload a mix of multiple non-compliant and unsafe products")
  end

  scenario "Adding non-compliant products" do
    visit "/products/bulk-upload/triage"

    expect(page).to have_content("How would you describe the products in terms of their compliance and safety?")

    choose "Products are non-compliant"
    click_button "Continue"

    expect(page).to have_error_summary("Enter why the product is non-compliant")
  end
end
