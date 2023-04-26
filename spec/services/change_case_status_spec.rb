require "rails_helper"

RSpec.describe ChangeCaseStatus, :with_stubbed_opensearch, :with_test_queue_adapter do
  describe ".call" do
    # Create the case before test run to ensure we only check activity generated by the test
    subject(:result) { described_class.call!(investigation:, new_status:, rationale:, user:) }

    let!(:investigation) { create(:enquiry, is_closed: false, creator: user, products: [product]) }
    let(:product) { create(:product, owning_team_id: user.team.id) }
    let(:previous_status) { "open" }
    let(:new_status) { "closed" }
    let(:rationale) { "Test" }
    let(:user) { create(:user, :activated) }
    let(:other_team) { create(:team) }
    let(:other_user) { create(:user, :activated, team: other_team) }

    context "with no investigation parameter" do
      subject(:result) { described_class.call(user:, new_status:) }

      it "fails" do
        expect(result).to be_failure
      end
    end

    context "with no user parameter" do
      subject(:result) { described_class.call(investigation:, new_status:) }

      it "fails" do
        expect(result).to be_failure
      end
    end

    context "with no new_status parameter" do
      subject(:result) { described_class.call(investigation:, user:) }

      it "fails" do
        expect(result).to be_failure
      end
    end

    context "when the previous status and the new status are the same" do
      let(:new_status) { previous_status }

      it "succeeds" do
        expect(result).to be_success
      end

      it "does not create a new activity" do
        expect { result }.not_to change(Activity, :count)
      end

      it "does not send an email" do
        expect { result }.not_to have_enqueued_mail(NotifyMailer, :investigation_updated)
      end
    end

    context "when the previous status and the new status are different" do
      def expected_email_subject
        "Case was closed"
      end

      def expected_email_body(name)
        "Case was closed by #{name}. Email notifications about edits made to cases are not sent when edits are made to closed cases."
      end

      it "succeeds" do
        expect(result).to be_success
      end

      it "changes the status for the investigation" do
        expect { result }.to change(investigation, :is_closed).from(false).to(true)
      end

      it "changes the date closed for the investigation" do
        expect { result }.to change(investigation, :date_closed).from(nil).to(kind_of(ActiveSupport::TimeWithZone))
      end

      it "changes investigation_closed_at for previously unclosed investigation_products" do
        result
        expect(investigation.reload.investigation_products.first.investigation_closed_at).to eq investigation.date_closed
      end

      it "does not change investigation_closed_at for previously closed investigation_products" do
        described_class.call!(investigation:, new_status: "closed", rationale:, user:)
        described_class.call!(investigation:, new_status: "open", rationale:, user:)
        result
        expect(investigation.reload.investigation_products.first.investigation_closed_at).not_to eq investigation.date_closed
      end

      it "creates a new activity for the change", :aggregate_failures do
        expect { result }.to change(Activity, :count).by(1)
        activity = investigation.reload.activities.first
        expect(activity).to be_a(AuditActivity::Investigation::UpdateStatus)
        expect(activity.added_by_user).to eq(user)
        expect(activity.metadata).to include("updates" => { "is_closed" => [false, true], "date_closed" => [nil, kind_of(String)] })
        expect(activity.metadata).to include("rationale" => rationale)
      end

      context "when the attached product is attached to another open case owned by the same team" do
        before do
          create(:enquiry, is_closed: false, creator: user, products: [product])
        end

        it "does not change product owner" do
          result
          expect(product.owning_team_id).to eq user.team.id
        end
      end

      context "when the attached product is attached to another closed case owned by the same team" do
        before do
          create(:enquiry, is_closed: true, creator: user, products: [product])
        end

        it "does not change product owner" do
          result
          expect(product.owning_team_id).to eq user.team.id
        end
      end

      context "when the attached product is attached to another case owned by a different team" do
        before do
          create(:enquiry, is_closed: false, creator: other_user, products: [product])
        end

        it "changes the product to unowned" do
          result
          expect(product.owning_team_id).to eq nil
        end
      end

      context "when the attached product is not attached to any other cases" do
        it "changes the product to unowned" do
          result
          expect(product.owning_team_id).to eq nil
        end
      end

      it_behaves_like "a service which notifies the case owner", even_when_the_case_is_closed: true
      it_behaves_like "a service which notifies the case creator", even_when_the_case_is_closed: true
    end
  end
end
