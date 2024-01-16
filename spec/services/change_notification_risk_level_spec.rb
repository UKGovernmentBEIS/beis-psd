RSpec.describe ChangeNotificationRiskLevel, :with_test_queue_adapter do
  subject(:result) do
    described_class.call(notification:, user:, risk_level: new_level)
  end

  let(:previous_level) { nil }
  let(:new_level) { nil }
  let(:creator_team) { notification.creator_user.team }
  let(:team_with_access) { create(:team, name: "Team with access", team_recipient_email: nil) }
  let(:user) { create(:user, :activated, has_viewed_introduction: true, team: team_with_access) }

  # Create the notification before test run to ensure we only check activity generated by the test
  let!(:notification) { create(:notification, risk_level: previous_level, edit_access_teams: [team_with_access]) }

  context "with no notification parameter" do
    subject(:result) do
      described_class.call(user:, risk_level: new_level)
    end

    it "fails" do
      expect(result).to be_failure
    end
  end

  context "with no user parameter" do
    subject(:result) do
      described_class.call(notification:, risk_level: new_level)
    end

    it "fails" do
      expect(result).to be_failure
    end
  end

  context "when the previous risk level and the new risk level are the same" do
    let(:previous_level) { "high" }
    let(:new_level) { "high" }

    it "succeeds" do
      expect(result).to be_success
    end

    it "does not create a new activity" do
      expect { result }.not_to change(Activity, :count)
    end

    it "does not send an email" do
      expect { result }.not_to have_enqueued_mail(NotifyMailer, :notification_risk_level_updated)
    end

    it "does not set a change action in the result context" do
      expect(result.change_action).to be_nil
    end

    it "does not set the updated risk level in the result context" do
      expect(result.updated_risk_level).to be_nil
    end
  end

  context "when the previous risk level was not set" do
    let(:previous_level) { nil }

    context "with a different new risk level" do
      let(:new_level) { "high" }

      it "succeeds" do
        expect(result).to be_success
      end

      it "sets the risk level for the notification" do
        expect { result }.to change(notification, :risk_level).from(previous_level).to(new_level)
      end

      it "creates a new activity for the risk level being set", :aggregate_failures do
        expect { result }.to change(Activity, :count).by(1)
        activity = notification.reload.activities.first
        expect(activity).to be_a(AuditActivity::Investigation::RiskLevelUpdated)
        expect(activity.metadata).to include(
          "updates" => { "risk_level" => [previous_level, new_level] },
          "update_verb" => "set"
        )
      end

      it "sends an email for the risk level being set" do
        expect { result }.to have_enqueued_mail(NotifyMailer, :notification_risk_level_updated).with(
          email: creator_team.team_recipient_email,
          name: creator_team.name,
          notification:,
          update_verb: "set",
          level: "High risk"
        )
      end

      it "sets a change action in the result context" do
        expect(result.change_action).to eq :set
      end

      it "sets the updated risk level in the result context" do
        expect(result.updated_risk_level).to eq "High risk"
      end
    end

    context "with empty new risk level" do
      let(:new_level) { "" }

      it "succeeds" do
        expect(result).to be_success
      end

      it "does not create a new activity" do
        expect { result }.not_to change(Activity, :count)
      end

      it "does not send an email" do
        expect { result }.not_to have_enqueued_mail(NotifyMailer, :notification_risk_level_updated)
      end

      it "does not set a change action in the result context" do
        expect(result.change_action).to be_nil
      end

      it "does not set the updated risk level in the result context" do
        expect(result.updated_risk_level).to be_nil
      end
    end
  end
end
