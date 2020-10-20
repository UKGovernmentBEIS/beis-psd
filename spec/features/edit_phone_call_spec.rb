require "rails_helper"

RSpec.feature "Edit a phone call correspondence", :with_stubbed_elasticsearch, :with_stubbed_antivirus, :with_stubbed_mailer, type: :feature do
  include_context "with phone call correspondence setup"

  let!(:correspondence) { AddPhoneCallToCase.call!(investigation: investigation, user: user, **params).correspondence.decorate }

  let(:new_correspondent_name)  { Faker::Movies::Hobbit.character }
  let(:new_phone_number)        { Faker::PhoneNumber.phone_number }
  let(:new_correspondence_date) { 2.days.ago.to_date }
  let(:new_overview)            { Faker::Hipster.sentence }
  let(:new_details)             { Faker::Hipster.sentence }
  let(:new_transcript)          { file_fixture("files/new_phone_call_transcript.txt") }

  before { sign_in investigation.owner_user }

  it "allows to edit the phone call record" do
    visit "/cases/#{investigation.pretty_id}/phone-calls/#{correspondence.id}"

    click_on "Edit phone call"

    expect(page).to have_title("Edit phone call: #{correspondence.title}")

    within_fieldset("Who was the call with?") do
      expect(page).to have_field("Name",         with: correspondence.correspondent_name)
      expect(page).to have_field("Phone number", with: correspondence.phone_number)
    end

    within_fieldset("Date of call") do
      expect(page).to have_field("Day",   with: correspondence.correspondence_date.day)
      expect(page).to have_field("Month", with: correspondence.correspondence_date.month)
      expect(page).to have_field("Year",  with: correspondence.correspondence_date.year)
    end

    expect(page).to have_field("Summary", with: correspondence.overview)

    within_fieldset("Details") do
      expect(page).to have_field("Notes", with: "\r\n" + correspondence.details, type: "textarea")
      expect(page).to have_link(correspondence.transcript_blob.filename.to_s)
    end

    within_fieldset("Who was the call with?") do
      fill_in "Name",         with: new_correspondent_name
      fill_in "Phone number", with: new_phone_number
    end

    within_fieldset("Date of call") do
      fill_in "Day",   with: new_correspondence_date.day
      fill_in "Month", with: new_correspondence_date.month
      fill_in "Year",  with: new_correspondence_date.year
    end

    fill_in "Summary", with: new_overview

    within_fieldset("Details") do
      fill_in "Notes", with: new_details

      page.first("details summary span", text: "Replace this file").click
      attach_file "Upload a file", new_transcript
    end

    click_on "Update phone call"

    expect_to_be_on_phone_call_page(case_id: investigation.pretty_id)

    expect(page).to have_summary_item(key: "Date of call", value: new_correspondence_date.to_s(:govuk))
    expect(page).to have_summary_item(key: "Call with",    value: "#{new_correspondent_name} (#{new_phone_number})")
    expect(page).to have_summary_item(key: "Transcript",   value: "#{new_transcript.basename} (30 Bytes)")
    expect(page).to have_summary_item(key: "Notes",        value: new_details)

    click_on "Back to allegation: #{investigation.pretty_id}"
    click_on "Activity"

    activity = correspondence.activities.find_by!(type: "AuditActivity::Correspondence::PhoneCallUpdated")

    item = page.find("p.govuk-body-s", text: activity.subtitle(investigation.owner_user)).sibling("div.govuk-body")

    expect(item).to have_text("Name: #{new_correspondent_name}")
    expect(item).to have_text("Phone number: #{new_phone_number}")
    expect(item).to have_text("Date of call: #{new_correspondence_date.to_s(:govuk)}")
    expect(item).to have_text("Summary: #{new_overview}")
    expect(item).to have_link(new_transcript.basename)
    expect(item).to have_text("Notes: #{new_details}")
  end
end
