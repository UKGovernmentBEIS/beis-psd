require "rails_helper"

RSpec.feature "Your Account", :with_stubbed_elasticsearch, :with_stubbed_mailer, type: :feature do
  let(:user) {
    create(:user,
           :activated,
           :opss_user,
           name: "Joe Jones",
           email: "joe.jones@testing.gov.uk",
           mobile_number: "07700 900000",
           teams: [create(:team, name: "Standards and testing")])
  }

  scenario "Changing your name (with validation error)" do
    sign_in user

    visit "/"
    first(:link, "Your account").click

    expect_to_be_on_your_account_page

    expect(page).to have_summary_item(key: "Name", value: "Joe Jones")
    expect(page).to have_summary_item(key: "Email address", value: "joe.jones@testing.gov.uk")
    expect(page).to have_summary_item(key: "Mobile number", value: "07700 900000")

    click_link "Change name"

    expect_to_be_on_change_name_page

    fill_in "Full name", with: ""
    click_button "Save"

    expect(page).to have_link("Enter your full name", href: "#name")

    fill_in "Full name", with: "Joe Smith"
    click_button "Save"

    expect_to_be_on_your_account_page
    expect(page).to have_summary_item(key: "Name", value: "Joe Smith")
  end

private

  def expect_to_be_on_your_account_page
    expect(page).to have_current_path("/account")
    expect(page).to have_selector("h1", text: "Your account")
  end

  def expect_to_be_on_change_name_page
    expect(page).to have_current_path("/account/name")
    expect(page).to have_selector("h1", text: "Change your name")
  end
end
