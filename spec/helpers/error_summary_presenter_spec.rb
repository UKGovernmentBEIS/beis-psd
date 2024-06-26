require "rails_helper"

RSpec.describe ErrorSummaryPresenter, :with_test_queue_adapter do
  describe "testing GOVUK forms with date fields" do
    context "when the form submitted is an Correspondence Email form" do
      let(:email_correspondence_form) { EmailCorrespondenceForm.new }
      let(:email_correspondence_form_with_date) { EmailCorrespondenceForm.new(correspondence_date: Date.new(2023, 2, 11), "correspondence_date(1i)" => 2020, "correspondence_date(2i)" => 1, "correspondence_date(3i)" => 20) }
      let(:email_correspondence_form_complete) { EmailCorrespondenceForm.new(correspondence_date: Date.new(2023, 2, 11), "correspondence_date(1i)" => 2020, "correspondence_date(2i)" => 1, "correspondence_date(3i)" => 20, email_file: Rack::Test::UploadedFile.new("spec/fixtures/files/email.txt")) }

      before do
        email_correspondence_form.invalid?
        email_correspondence_form_with_date.invalid?
      end

      context "when no parameters supplied" do
        it "returns the expected errors" do
          presenter = described_class.new(email_correspondence_form.errors.to_hash(full_messages: true))
          formatted_errors = presenter.formatted_error_messages
          expected_errors = [[:correspondence_date, "Enter the date sentEnter the date sent"], [:base, "Please provide either an email file or a subject and body"]]
          expect(formatted_errors).to eq(expected_errors)
        end
      end

      context "when :correspondence_date parameter supplied" do
        it "does not return :correspondence_date error" do
          presenter = described_class.new(email_correspondence_form_with_date.errors.to_hash(full_messages: true))
          formatted_errors = presenter.formatted_error_messages
          expected_errors = [[:base, "Please provide either an email file or a subject and body"]]
          expect(formatted_errors).to eq(expected_errors)
        end
      end

      context "when all parameters supplied" do
        it "does not return any errors" do
          presenter = described_class.new(email_correspondence_form_complete.errors.to_hash(full_messages: true))
          formatted_errors = presenter.formatted_error_messages
          expected_errors = []
          expect(formatted_errors).to eq(expected_errors)
        end
      end
    end
  end
end
