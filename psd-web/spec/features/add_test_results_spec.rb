require "rails_helper"

RSpec.feature "Adding a test result", :with_stubbed_elasticsearch, :with_stubbed_antivirus, :with_stubbed_mailer do
  let(:user) { create(:user, :activated, has_viewed_introduction: true) }
  let(:product) { create(:product_washing_machine, name: "MyBrand washing machine") }
  let(:investigation) { create(:allegation, products: [product], creator: user, owner: user) }
  let(:date) { Date.parse("1 Jan 2020") }
  let(:file) { Rails.root + "test/fixtures/files/test_result.txt" }
  let(:other_user) { create(:user, :activated) }
  let(:legislation) { "General Product Safety Regulations 2005" }

  scenario "Adding a test result (with validation errors)" do
    travel_to Date.parse("2 April 2020") do
      sign_in(user)
      visit "/cases/#{investigation.pretty_id}/supporting-information"

      click_link "Add supporting information"

      expect_to_be_on_add_supporting_information_page

      within_fieldset "What type of information are you adding?" do
        page.choose "Test result"
      end
      click_button "Continue"

      expect_to_be_on_record_test_result_page
      click_button "Continue"

      expect(page).to have_summary_error("Enter date of the test")
      expect(page).to have_summary_error("Select the legislation that relates to this test")
      expect(page).to have_summary_error("Select result of the test")
      expect(page).to have_summary_error("Provide the test results file")

      fill_in "Further details", with: "Test result includes certificate of conformity"
      fill_in_test_result_submit_form(legislation: "General Product Safety Regulations 2005", date: date, test_result: "test_result_passed", file: file)

      expect_test_result_confirmation_page_to_show_entered_data(legislation: legislation, date: date, test_result: "Passed")

      click_on "Edit details"

      expect_to_be_on_record_test_result_page

      expect_test_result_form_to_show_input_data(legislation: legislation, date: date)

      click_button "Continue"

      expect_test_result_confirmation_page_to_show_entered_data(legislation: legislation, date: date, test_result: "Passed")

      click_button "Continue"

      expect_confirmation_banner("Test result was successfully recorded.")
      expect_page_to_have_h1("Supporting information")

      click_link "Activity"

      expect_to_be_on_case_activity_page(case_id: investigation.pretty_id)
      expect(page).to have_text("Passed test: MyBrand washing machine")

      click_link "View test result"

      expect_to_be_on_test_result_page(case_id: investigation.pretty_id)

      expect(page).to have_summary_item(key: "Date of test", value: "1 January 2020")
      expect(page).to have_summary_item(key: "Legislation", value: "General Product Safety Regulations 2005")
      expect(page).to have_summary_item(key: "Result", value: "Passed")
      expect(page).to have_summary_item(key: "Further details", value: "Test result includes certificate of conformity")
      expect(page).to have_summary_item(key: "Attachment description", value: "test result file")

      expect(page).to have_text("test_result.txt")
    end
  end

  scenario "Not being able to add test results to another team’s case" do
    sign_in(other_user)
    visit "/cases/#{investigation.pretty_id}/activity"

    expect(page).not_to have_link("Add supporting information")
  end

  def fill_in_test_result_submit_form(legislation:, date:, test_result:, file:)
    select legislation, from: "test_legislation"
    fill_in "Day",   with: date.day if date
    fill_in "Month", with: date.month if date
    fill_in "Year",  with: date.year  if date
    choose test_result
    attach_file "test[file][file]", file
    fill_in "test_file_description", with: "test result file"
    click_button "Continue"
    expect(page).to have_css("h1", text: "Confirm test result details")
  end

  def expect_test_result_form_to_show_input_data(legislation:, date:)
    expect(page).to have_field("test_legislation", with: legislation)
    expect(page).to have_field("Day", with: date.day)
    expect(page).to have_field("Month", with: date.month)
    expect(page).to have_field("Year", with: date.year)
    expect(page).to have_field("test_result_passed", with: "passed")
    expect(page).to have_field("test_file_description", with: "\r\ntest result file")
  end

  def expect_test_result_confirmation_page_to_show_entered_data(legislation:, date:, test_result:)
    expect(page).to have_css("h1", text: "Confirm test result details")
    expect(page).to have_summary_table_item(key: "Legislation", value: legislation)
    expect(page).to have_summary_table_item(key: "Test date", value: date.strftime("%d/%m/%Y"))
    expect(page).to have_summary_table_item(key: "Test result", value: test_result)
    expect(page).to have_summary_table_item(key: "Attachment", value: File.basename(file))
    expect(page).to have_summary_table_item(key: "Attachment description", value: "test result file")
  end
end
