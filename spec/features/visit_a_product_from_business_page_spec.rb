require "rails_helper"

RSpec.feature "Notification task list", :with_stubbed_antivirus, :with_stubbed_mailer, :with_opensearch, :with_product_form_helper do
  let(:user) { create(:user, :opss_user, :activated, has_viewed_introduction: true, roles: %w[notification_task_list_user]) }
  let(:existing_product) { create(:product) }
  let(:new_product_attributes) do
    attributes_for(:product_iphone, authenticity: Product.authenticities.keys.without("missing", "unsure").sample)
  end
  let(:image_file) { Rails.root.join "test/fixtures/files/testImage.png" }
  let(:text_file) { Rails.root.join "test/fixtures/files/attachment_filename.txt" }

  before do
    sign_in(user)

    existing_product
  end

  scenario "Creating a notification with the normal flow then going to product page from business page" do
    visit "/notifications/create"
    expect(page).to have_current_path(/\/notifications\/\d{4}-\d{4}\/create/)
    expect(page).to have_content("Create a product safety notification")
    expect(page).to have_selector(:id, "task-list-0-0-status", text: "Not yet started")

    click_link "Search for or add a product"
    click_button "Select", match: :first

    within_fieldset "Do you need to add another product?" do
      choose "No"
    end

    click_button "Continue"

    expect(page).to have_selector(:id, "task-list-0-0-status", text: "Completed")
    expect(page).to have_content("You have completed 1 of 6 sections.")

    click_link "Add notification details"
    fill_in "Notification title", with: "Fake name"
    fill_in "Notification summary", with: "This is a fake summary"
    within_fieldset("Why are you creating the notification?") do
      choose "A product is unsafe or non-compliant"
    end
    click_button "Save and continue"

    within_fieldset "What specific issues make the product unsafe or non-compliant?" do
      check "Product harm"
      select "Chemical", from: "What is the primary harm?"
      fill_in "Provide additional information about the product harm", with: "Fake description"
    end

    within_fieldset "Was the safety issue reported by an overseas regulator?" do
      choose "Yes"
      select "France", from: "Country"
    end

    within_fieldset "Do you want to add your own reference number?" do
      choose "Yes"
      fill_in "Reference number", with: "123456"
    end

    click_button "Save and continue"

    choose "Unknown"
    click_button "Save and complete tasks in this section"

    expect(page).to have_selector(:id, "task-list-1-0-status", text: "Completed")
    expect(page).to have_selector(:id, "task-list-1-1-status", text: "Completed")
    expect(page).to have_selector(:id, "task-list-1-2-status", text: "Completed")
    expect(page).to have_content("You have completed 2 of 6 sections.")

    click_link "Search for or add a business"
    click_link "Add a new business"
    fill_in "Trading name", with: "Trading name"
    fill_in "Registered or legal name (optional)", with: "Legal name"
    click_button "Save and continue"

    fill_in "Address line 1", with: "123 Fake St"
    fill_in "Address line 2", with: "Fake Heath"
    fill_in "Town or city", with: "Faketon"
    fill_in "County", with: "Fake County"
    fill_in "Post code", with: "FA1 2KE"
    select "United Kingdom", from: "Country"
    click_button "Save and continue"

    fill_in "Full name", with: "Max Mustermann"
    fill_in "Job title or role description", with: "Manager"
    fill_in "Email", with: "max@example.com"
    fill_in "Phone", with: "+441121121212"
    click_button "Save and continue"

    click_button "Use business details"

    check "Retailer"
    click_button "Save and continue"

    within_fieldset "Do you need to add another business?" do
      choose "No"
    end
    click_button "Continue"

    expect(page).to have_selector(:id, "task-list-2-0-status", text: "Completed")
    expect(page).to have_content("You have completed 3 of 6 sections.")

    # Ensure that all of section 4 and the first task of section are enabled once section 3 is completed
    expect(page).to have_selector(:id, "task-list-3-0-status", text: "Not yet started")
    expect(page).to have_selector(:id, "task-list-3-1-status", text: "Not yet started")
    expect(page).to have_selector(:id, "task-list-3-2-status", text: "Not yet started")
    expect(page).to have_selector(:id, "task-list-3-3-status", text: "Not yet started")
    expect(page).to have_selector(:id, "task-list-3-4-status", text: "Not yet started")
    expect(page).to have_selector(:id, "task-list-3-5-status", text: "Not yet started")
    expect(page).to have_selector(:id, "task-list-4-0-status", text: "Not yet started")

    click_link "Add product identification details"
    click_link "Add batch numbers"
    fill_in "batch_number", with: "1234, 5678"
    click_button "Save"
    click_button "Continue"

    click_link "Add test reports"
    choose "Yes"
    click_button "Save and continue"

    fill_in "What is the trading standards officer sample reference number?", with: "12345678"
    fill_in "Day", with: "12"
    fill_in "Month", with: "5"
    fill_in "Year", with: "2023"
    click_button "Save and continue"

    select "ATEX 2016", from: "Under which legislation?"
    fill_in "Which standard was the product tested against?", with: "EN71"
    fill_in "Day", with: "12"
    fill_in "Month", with: "5"
    fill_in "Year", with: "2023"

    within_fieldset "What was the result?" do
      choose "Fail"
      fill_in "How the product failed", with: "Because it did"
    end

    attach_file "Test report attachment", image_file
    click_button "Add test report"

    expect(page).to have_content("You have added 1 test report.")

    within_fieldset "Do you need to add another test report?" do
      choose "No"
    end

    click_button "Continue"

    expect(page).to have_selector(:id, "task-list-3-0-status", text: "Completed")

    click_link "Add supporting images"

    attach_file "image_upload[file_upload]", image_file
    click_button "Upload image"

    expect(page).to have_content("Supporting image uploaded successfully")

    click_button "Finish uploading images"

    expect(page).to have_selector(:id, "task-list-3-1-status", text: "Completed")

    click_link "Add supporting documents"

    fill_in "Document title", with: "Fake title"
    attach_file "document_form[document]", text_file
    click_button "Upload document"

    expect(page).to have_content("Supporting document uploaded successfully")

    click_button "Finish uploading documents"

    expect(page).to have_selector(:id, "task-list-3-2-status", text: "Completed")

    click_link "Add risk assessments"
    click_link "Add legacy risk assessment"

    within_fieldset "Date of assessment" do
      fill_in "Day", with: "12"
      fill_in "Month", with: "5"
      fill_in "Year", with: "2023"
    end

    within_fieldset "What was the risk level?" do
      choose "High risk"
    end

    within_fieldset "Who completed the assessment?" do
      choose "Someone else"
      fill_in "Organisation name", with: "Fake org"
    end

    attach_file "risk_assessment_form[risk_assessment_file]", text_file

    click_button "Add risk assessment"

    expect(page).to have_content("You have added 1 risk assessment.")

    within_fieldset "Do you need to add another risk assessment?" do
      choose "No"
    end

    click_button "Continue"

    expect(page).to have_selector(:id, "task-list-3-3-status", text: "Completed")

    click_link "Evaluate notification risk level"

    expect(page).to have_content("This notification has 1 risk assessment added, assessing the risk as high.")

    choose "Medium risk"

    click_button "Save and complete tasks in this section"

    expect(page).to have_selector(:id, "task-list-3-4-status", text: "Completed")
    expect(page).to have_content("You have completed 4 of 6 sections.")

    click_link "Record a corrective action"

    within_fieldset "Have you taken a corrective action for the unsafe or non-compliant product(s)?" do
      choose "Yes"
    end

    click_button "Save and continue"

    within_fieldset "What action is being taken?" do
      choose "Recall of the product from end users"
    end

    within_fieldset "Has the business responsible published product recall information online?" do
      choose "Yes"
      fill_in "Location of recall information", with: "https://www.example.com"
    end

    within_fieldset "What date did the action come in to effect?" do
      fill_in "Day", with: "9"
      fill_in "Month", with: "2"
      fill_in "Year", with: "2024"
    end

    select "ATEX 2016", from: "Under which legislation?"
    select "Consumer Protection Act 1987", from: "Under which legislation?"

    within_fieldset "Which business is responsible?" do
      choose "Trading name (Retailer)"
      # TODO: add test here once business selection is possible
    end

    within_fieldset "Is the corrective action mandatory?" do
      choose "Yes"
    end

    within_fieldset "In which geographic regions has this corrective action been taken?" do
      check "Great Britain"
      check "European Economic Area (EEA)"
    end

    within_fieldset "Are there any files related to the action?" do
      choose "Yes"
      attach_file "corrective_action_form[document]", text_file
    end

    click_button "Add corrective action"

    expect(page).to have_content("You have added 1 corrective action.")

    within_fieldset "Do you need to add another corrective action?" do
      choose "No"
    end

    click_button "Continue"

    expect(page).to have_selector(:id, "task-list-4-0-status", text: "Completed")
    expect(page).to have_content("You have completed 5 of 6 sections.")

    click_link "Check the notification details and submit"
    click_button "Submit notification"

    expect(page).to have_content("Notification submitted")
    visit "/businesses/your-businesses"
    click_link "Trading name"
    expect(page).to have_current_path(/\/businesses\/\d/)
    click_link "Products (#{existing_product.investigations.size})"
    click_link "psd-#{existing_product.id}"
    expect(page).to have_current_path("/products/#{existing_product.id}")
  end
end
