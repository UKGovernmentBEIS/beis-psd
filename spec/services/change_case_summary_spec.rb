require "rails_helper"

RSpec.describe ChangeCaseSummary, :with_stubbed_elasticsearch, :with_test_queue_adapter do
  # Create the investigation up front so we can check which activities are generated by the service
  let!(:investigation) { create(:enquiry, description: old_summary) }
  let(:old_summary) { "Old summary" }
  let(:new_summary) { "New summary" }
  let(:user) { create(:user, :activated) }

  describe ".call" do
    context "with no parameters" do
      let(:result) { described_class.call }

      it "returns a failure" do
        expect(result).to be_failure
      end
    end

    context "with no investigation parameter" do
      let(:result) { described_class.call(summary: new_summary, user: user) }

      it "returns a failure" do
        expect(result).to be_failure
      end
    end

    context "with no user parameter" do
      let(:result) { described_class.call(summary: new_summary, investigation: investigation) }

      it "returns a failure" do
        expect(result).to be_failure
      end
    end

    context "with no summary parameter" do
      let(:result) { described_class.call(investigation: investigation, user: user) }

      it "returns a failure" do
        expect(result).to be_failure
      end
    end

    context "with required parameters" do
      def expected_email_subject
        "Enquiry summary updated"
      end

      def expected_email_body(name)
        "Enquiry summary was updated by #{name}."
      end

      let(:result) { described_class.call(investigation: investigation, user: user, summary: new_summary) }

      it "returns success" do
        expect(result).to be_success
      end

      context "when the new summary is the same as the old summary" do
        let(:new_summary) { old_summary }

        it "returns success" do
          expect(result).to be_success
        end

        it "does not create an audit activity" do
          expect { result }.not_to change(Activity, :count)
        end

        it "does not send an email" do
          expect { result }.not_to have_enqueued_mail(NotifyMailer, :investigation_updated)
        end
      end

      it "changes the case summary" do
        expect { result }.to change(investigation, :description).from(old_summary).to(new_summary)
      end

      it "creates an audit activity for summary changed", :aggregate_failures do
        expect { result }.to change(Activity, :count).by(1)
        activity = investigation.reload.activities.first
        expect(activity).to be_a(AuditActivity::Investigation::UpdateSummary)
        expect(activity.source.user).to eq(user)
        expect(activity.metadata).to eq({ "updates" => { "description" => ["Old summary", "New summary"] } })
      end

      it_behaves_like "a service which notifies the case owner"
    end
  end
end
