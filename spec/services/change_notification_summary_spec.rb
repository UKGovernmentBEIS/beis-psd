RSpec.describe ChangeNotificationSummary, :with_test_queue_adapter do
  # Create the notification up front so we can check which activities are generated by the service
  let!(:notification) { create(:notification, description: old_summary) }
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

    context "with no notification parameter" do
      let(:result) { described_class.call(summary: new_summary, user:) }

      it "returns a failure" do
        expect(result).to be_failure
      end
    end

    context "with no user parameter" do
      let(:result) { described_class.call(summary: new_summary, notification:) }

      it "returns a failure" do
        expect(result).to be_failure
      end
    end

    context "with no summary parameter" do
      let(:result) { described_class.call(notification:, user:) }

      it "returns a failure" do
        expect(result).to be_failure
      end
    end

    context "with required parameters" do
      def expected_email_subject
        "Notification summary updated"
      end

      def expected_email_body(name)
        "Notification summary was updated by #{name}."
      end

      let(:result) { described_class.call(notification:, user:, summary: new_summary) }

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
          expect { result }.not_to have_enqueued_mail(NotifyMailer, :notification_updated)
        end
      end

      it "changes the case summary" do
        expect { result }.to change(notification, :description).from(old_summary).to(new_summary)
      end

      it "creates an audit activity for summary changed", :aggregate_failures do
        expect { result }.to change(Activity, :count).by(1)
        activity = notification.reload.activities.first
        expect(activity).to be_a(AuditActivity::Investigation::UpdateSummary)
        expect(activity.added_by_user).to eq(user)
        expect(activity.metadata).to eq({ "updates" => { "description" => ["Old summary", "New summary"] } })
      end

      it_behaves_like "a service which notifies the notification owner"
    end
  end
end
