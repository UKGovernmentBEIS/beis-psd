require "rails_helper"

RSpec.describe CreateCase, :with_stubbed_opensearch, :with_test_queue_adapter do
  let(:investigation) { build(:enquiry, creator: user) }
  let(:user) { create(:user) }

  describe ".call" do
    context "with no parameters" do
      let(:result) { described_class.call }

      it "returns a failure" do
        expect(result).to be_failure
      end
    end

    context "with no investigation parameter" do
      let(:result) { described_class.call(user:) }

      it "returns a failure" do
        expect(result).to be_failure
      end
    end

    context "with no user parameter" do
      let(:result) { described_class.call(investigation:) }

      it "returns a failure" do
        expect(result).to be_failure
      end
    end

    context "with required parameters" do
      let(:result) { described_class.call(investigation:, user:) }

      it "returns success" do
        expect(result).to be_success
      end

      context "when there is no creator user already on the investigation" do
        before { investigation.creator_user = nil }

        it "sets one" do
          result
          expect(investigation.reload.creator_user).to eq(user)
        end
      end

      context "when there is no owner already on the investigation" do
        before do
          investigation.owner_user_collaboration = nil
          investigation.owner_team_collaboration = nil
        end

        it "sets the owner to the user", :aggregate_failures do
          result

          investigation.reload
          expect(investigation.owner_user_collaboration.collaborator).to eq(user)
          expect(investigation.owner_team_collaboration.collaborator).to eq(user.team)
        end
      end

      it "generates a pretty_id" do
        result
        expect(investigation.reload.pretty_id).to be_a(String)
      end

      context "with previous investigations" do
        let(:investigations) { build_list(:enquiry, 3, creator: user) }

        before { investigations.each { |i| described_class.call(investigation: i, user:) } }

        it "generates a successive pretty_id", :aggregate_failures do
          expect(Investigation.pluck(:pretty_id).map { |id| id.split("-").last })
            .to eq(%w[0001 0002 0003])
          result
          expect(investigation.reload.pretty_id).to end_with("0004")
        end

        it "does not generate a conflicting pretty_id following a case deletion", :aggregate_failures do
          investigations.second.destroy!
          expect(Investigation.pluck(:pretty_id).map { |id| id.split("-").last })
            .to eq(%w[0001 0003])
          result
          expect(investigation.reload.pretty_id).to end_with("0004")
        end
      end

      it "creates an audit activity for case created", :aggregate_failures do
        result
        activity = investigation.reload.activities.first
        expect(activity).to be_a(AuditActivity::Investigation::AddEnquiry)
        expect(activity.added_by_user).to eq(user)
        expect(activity.metadata).to eq(AuditActivity::Investigation::AddEnquiry.build_metadata(investigation).deep_stringify_keys)
      end

      context "when there are products added to the case" do
        let(:investigation) { build(:allegation, products: [product], creator: user) }
        let(:product) { create(:product_washing_machine) }

        it "creates an audit activity for product added", :aggregate_failures do
          result
          activity = investigation.reload.activities.first
          expect(activity).to be_a(AuditActivity::Product::Add)
          expect(activity.added_by_user).to eq(user)
          expect(activity.product).to eq(product)
          expect(activity.title(user)).to eq(product.name)
        end
      end

      it "sends a notification email to the case creator" do
        expect { result }.to have_enqueued_mail(NotifyMailer, :investigation_created).with(
          kind_of(String),
          user.name,
          user.email,
          "test enquiry title",
          "enquiry"
        )
      end
    end
  end
end
