require "rails_helper"

RSpec.describe ChangeCaseOwner, :with_stubbed_elasticsearch, :with_test_queue_adapter do
  # Create the investigation up front so we can check which activities are generated by the service

  let(:team) { create(:team) }

  let(:creator) { create(:user, :activated, team: team, organisation: team.organisation) }
  let(:old_owner) { creator }
  let(:new_team) { team }
  let(:new_owner) { create(:user, :activated, team: new_team, organisation: team.organisation) }
  let(:user) { create(:user, :activated, team: team, organisation: team.organisation) }
  let(:rationale) { "Test rationale" }

  let!(:investigation) { create(:enquiry, owner: old_owner, creator: creator) }

  describe ".call" do
    context "with no parameters" do
      let(:result) { described_class.call }

      it "returns a failure" do
        expect(result).to be_failure
      end
    end

    context "with no investigation parameter" do
      let(:result) { described_class.call(owner: new_owner, user: user) }

      it "returns a failure" do
        expect(result).to be_failure
      end
    end

    context "with no user parameter" do
      let(:result) { described_class.call(owner: new_owner, investigation: investigation) }

      it "returns a failure" do
        expect(result).to be_failure
      end
    end

    context "with no owner parameter" do
      let(:result) { described_class.call(investigation: investigation, user: user) }

      it "returns a failure" do
        expect(result).to be_failure
      end
    end

    context "with required parameters" do
      let(:result) { described_class.call(investigation: investigation, user: user, owner: new_owner, rationale: rationale) }

      it "returns success" do
        expect(result).to be_success
      end

      context "when the new owner is the same as the old owner" do
        let(:new_owner) { old_owner }

        it "does not create an audit activity" do
          expect { result }.not_to change(Activity, :count)
        end

        it "does not send an email" do
          expect { result }.not_to have_enqueued_mail(NotifyMailer, :investigation_updated)
        end
      end

      it "changes the owner" do
        expect { result }.to change(investigation, :owner).from(old_owner).to(new_owner)
      end

      it "creates an audit activity for owner changed", :aggregate_failures do
        expect { result }.to change(Activity, :count).by(1)
        activity = investigation.reload.activities.first
        expect(activity).to be_a(AuditActivity::Investigation::UpdateOwner)
        expect(activity.source.user).to eq(user)
        expect(activity.metadata).to eq(AuditActivity::Investigation::UpdateOwner.build_metadata(new_owner, rationale).deep_stringify_keys)
      end

      it "sends a notification email to the new owner" do
        expect { result }.to have_enqueued_mail(NotifyMailer, :investigation_updated).with(
          investigation.pretty_id,
          new_owner.name,
          new_owner.email,
          expected_email_body,
          expected_email_subject
        )
      end

      it "sends a notification email to the old owner" do
        expect { result }.to have_enqueued_mail(NotifyMailer, :investigation_updated).with(
          investigation.pretty_id,
          old_owner.name,
          old_owner.email,
          expected_email_body,
          expected_email_subject
        )
      end

      context "when no rationale is supplied" do
        let(:rationale) { nil }

        it "does not add a message to the notification email" do
          expect { result }.to have_enqueued_mail(NotifyMailer, :investigation_updated).with(
            investigation.pretty_id,
            old_owner.name,
            old_owner.email,
            "Case owner changed on enquiry to #{new_owner.name} by #{user.name}.",
            expected_email_subject
          )
        end
      end

      context "when the user is the same as the old owner" do
        let(:user) { old_owner }

        it "does not send a notification email to the old owner" do
          expect { result }.not_to have_enqueued_mail(NotifyMailer, :investigation_updated).with(
            investigation.pretty_id,
            old_owner.name,
            old_owner.email,
            expected_email_body,
            expected_email_subject
          )
        end
      end

      context "when the new owner is a Team" do
        let(:new_owner) { team }

        context "when the team has a an email address" do
          let(:team) { create(:team, team_recipient_email: Faker::Internet.email) }

          it "sends a notification email to the team" do
            expect { result }.to have_enqueued_mail(NotifyMailer, :investigation_updated).with(
              investigation.pretty_id,
              team.name,
              team.team_recipient_email,
              expected_email_body,
              expected_email_subject
            )
          end
        end

        context "when the team does not have an email address" do
          let(:team) { create(:team, team_recipient_email: nil) }

          # Create an inactive user to test email is not delivered to them
          before { create(:user, team: team, organisation: team.organisation) }

          it "sends an email to each of the team's active users" do
            expect { result }.to have_enqueued_mail(NotifyMailer, :investigation_updated).twice
          end
        end
      end

      describe "adding old owner as collaborator" do
        shared_examples "collaborator created" do
          it "creates collaboration with edit access" do
            expect { result }.to change { Collaboration::EditAccess.count }.from(0).to(1)
          end

          it "creates proper collaboration" do
            result
            expect(investigation.teams_with_edit_access).to eq([creator_team])
          end
        end

        shared_examples "collaborator not created" do
          let(:result) { described_class.call(investigation: investigation, user: user, owner: new_owner, rationale: rationale) }

          it "creates no collaboration" do
            expect { result }.not_to change { Collaboration::EditAccess.count }
          end
        end

        let(:other_team)   { create(:team) }
        let(:creator_team) { team }

        context "when old owner is team, new owner is team" do
          let(:old_owner) { team }
          let(:new_owner) { other_team }
          include_examples "collaborator created"
        end

        context "when old owner is user, new owner is team" do
          let(:old_owner) { creator }
          let(:new_owner) { other_team }

          include_examples "collaborator created"
        end

        context "when old owner is user, new owner is user" do
          let(:old_owner) { creator }
          let(:new_owner) { create(:user, :activated, team: other_team, organisation: other_team.organisation) }

          include_examples "collaborator created"
        end

        context "when old owner is team, new owner is user" do
          let(:old_owner) { team }
          let(:new_owner) { create(:user, :activated, team: other_team, organisation: other_team.organisation) }

          include_examples "collaborator created"
        end

        context "when old owner is team, new owner is user from the same team" do
          let(:old_owner) { team }
          let(:new_owner) { create(:user, :activated, team: team, organisation: team.organisation) }

          include_examples "collaborator not created"
        end

        context "when old owner is user, new owner is user from the same team" do
          let(:new_owner) { create(:user, :activated, team: team, organisation: team.organisation) }

          include_examples "collaborator not created"
        end

        context "when old owner is user, new owner is old owner team" do
          let(:new_owner) { team }

          include_examples "collaborator not created"
        end
      end
    end
  end

  def expected_email_subject
    "Case owner changed for enquiry"
  end

  def expected_email_body
    "Case owner changed on enquiry to #{new_owner.name} by #{user.name}.\n\nMessage from #{user.name}: ^ Test rationale"
  end
end
