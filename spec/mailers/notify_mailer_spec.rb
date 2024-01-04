require "rails_helper"

RSpec.describe NotifyMailer, :with_stubbed_opensearch do
  describe "#reset_password_instruction" do
    let(:user)  { build(:user) }
    let(:token) { SecureRandom.hex }
    let(:mail)  { described_class.reset_password_instructions(user, token) }

    it "sets the recipient of the email" do
      expect(mail.to).to eq([user.email])
    end

    it "sets the template ID" do
      expect(mail.govuk_notify_template).to eq(described_class::TEMPLATES[:reset_password_instruction])
    end

    it "sets the GOV.UK Notify reference" do
      expect(mail.govuk_notify_reference).to eq("Password reset")
    end

    it "sets the personalisation attributes" do
      expect(mail.govuk_notify_personalisation)
        .to eq(name: user.name, edit_user_password_url_token: edit_user_password_url(reset_password_token: token))
    end
  end

  describe "#product_export" do
    let(:user)           { create(:user) }
    let(:params)         { {} }
    let(:product_export) { ProductExport.create!(user:, params:) }

    let(:mail) { described_class.product_export(email: user.email, name: user.name, product_export:) }

    it "sets the recipient of the email" do
      expect(mail.to).to eq([user.email])
    end

    it "sets the template ID" do
      expect(mail.govuk_notify_template).to eq(described_class::TEMPLATES[:product_export])
    end

    it "sets the GOV.UK Notify reference" do
      expect(mail.govuk_notify_reference).to eq("Product Export")
    end

    it "sets the personalisation attributes" do
      expect(mail.govuk_notify_personalisation)
        .to eq(name: user.name, download_export_url: product_export_url(product_export))
    end
  end

  describe "#case_export" do
    let(:user) { create(:user) }
    let(:params) { {} }
    let(:case_export) { CaseExport.create!(user:, params:) }

    let(:mail) { described_class.case_export(email: user.email, name: user.name, case_export:) }

    it "sets the recipient of the email" do
      expect(mail.to).to eq([user.email])
    end

    it "sets the template ID" do
      expect(mail.govuk_notify_template).to eq(described_class::TEMPLATES[:case_export])
    end

    it "sets the GOV.UK Notify reference" do
      expect(mail.govuk_notify_reference).to eq("Notification Export")
    end

    it "sets the personalisation attributes" do
      expect(mail.govuk_notify_personalisation)
        .to eq(name: user.name, download_export_url: case_export_url(case_export))
    end
  end

  describe "#account_locked_inactive" do
    let(:user) { create(:user) }
    let(:token) { "abc" }
    let(:mail) { described_class.account_locked_inactive(user, token) }

    it "sets the recipient of the email" do
      expect(mail.to).to eq([user.email])
    end

    it "sets the template ID" do
      expect(mail.govuk_notify_template).to eq(described_class::TEMPLATES[:account_locked_inactive])
    end

    it "sets the personalisation attributes" do
      expect(mail.govuk_notify_personalisation)
        .to eq(name: user.name, unlock_user_url_token: user_unlock_url(unlock_token: token))
    end
  end

  describe "#invitation_email" do
    context "when called with a user and an inviting user" do
      let(:user)  { create(:user, :invited) }
      let(:inviting_user) { build(:user) }

      let(:mail) { described_class.invitation_email(user, inviting_user) }

      it "sets the recipient of the email" do
        expect(mail.to).to eq([user.email])
      end

      it "sets the template ID" do
        expect(mail.govuk_notify_template).to eq("7b80a680-f8b3-4032-982d-2a3a662b611a")
      end

      it "sets the personalisation attributes" do
        invitation_url = complete_registration_user_url(user.id, invitation: user.invitation_token)

        expect(mail.govuk_notify_personalisation)
          .to eq(invitation_url:, inviting_team_member_name: inviting_user.name)
      end
    end

    context "when called with a user and no inviting user" do
      let(:user)  { create(:user, :invited) }

      let(:mail)  { described_class.invitation_email(user, nil) }

      it "sets the personalisation attributes" do
        invitation_url = complete_registration_user_url(user.id, invitation: user.invitation_token)

        expect(mail.govuk_notify_personalisation)
          .to eq(invitation_url:, inviting_team_member_name: "a colleague")
      end
    end
  end

  describe "#team_added_to_case_email" do
    subject(:mail) { described_class.team_added_to_case_email(investigation:, team:, added_by_user: user, message:, to_email: "test@example.com") }

    let(:investigation) { create(:allegation, creator: user) }
    let(:user) { create(:user, :activated, name: "Bob Jones") }
    let(:team) { create(:team) }

    context "with a message" do
      let(:message) { "Thanks for collaborating!" }

      it "sets the personalisation" do
        expect(mail.govuk_notify_personalisation).to eql(
          updater_name: "Bob Jones (#{user.team.name})",
          optional_message: "Message from Bob Jones (#{user.team.name}):\n\n^ Thanks for collaborating!",
          investigation_url: investigation_url(investigation)
        )
      end
    end

    context "with no message" do
      let(:message) { nil }

      it "sets the personalisation" do
        expect(mail.govuk_notify_personalisation).to eql(
          updater_name: "Bob Jones (#{user.team.name})",
          optional_message: "",
          investigation_url: investigation_url(investigation)
        )
      end
    end
  end

  describe "#team_removed_from_notification_email" do
    subject(:mail) do
      described_class.team_removed_from_notification_email(
        message:,
        notification:,
        team_deleted: team_to_be_deleted,
        user_who_deleted:,
        to_email: "test@example.com"
      )
    end

    let(:user_who_deleted) { create(:user, name: "Bob Jones", team: user_team) }
    let(:user_team) { create(:team, name: "User Team") }
    let(:team_to_be_deleted) { create(:team, name: "Collaborator Team") }
    let(:edit_access_collaboration) { create(:collaboration_edit_access, collaborator: team_to_be_deleted) }
    let(:notification) { edit_access_collaboration.investigation }
    let(:case_type) { "notification" }
    let(:case_title) { notification.decorate.title }

    context "with a message" do
      let(:message) { "Thanks for collaborating!" }

      it "sets the personalisation" do
        expect_personalisation_to_include_notification_attributes
        expect(mail.govuk_notify_personalisation).to include(
          updater_name: "Bob Jones (User Team)",
          optional_message: "Message from Bob Jones (User Team):\n\n^ Thanks for collaborating!",
        )
      end
    end

    context "with no message" do
      let(:message) { nil }

      it "sets the personalisation" do
        expect_personalisation_to_include_notification_attributes
        expect(mail.govuk_notify_personalisation).to include(
          updater_name: "Bob Jones (User Team)",
          optional_message: "",
        )
      end
    end
  end

  describe "#notification_updated" do
    subject(:mail) do
      described_class.notification_updated(
        notification.pretty_id,
        user.name,
        user.email,
        update_text,
        subject_text
      )
    end

    let(:notification) { create(:notification, creator: user) }
    let(:user) { create(:user, :activated, name: "Bob Jones") }
    let(:update_text) { "thing updated" }
    let(:subject_text) { "subject" }

    it "sets the personalisation" do
      expect(mail.govuk_notify_personalisation).to include(
        name: "Bob Jones",
        update_text: "thing updated",
        subject_text: "subject",
        investigation_url: investigation_url(pretty_id: notification.pretty_id)
      )
    end
  end

  describe "#case_permission_changed_for_team" do
    subject(:mail) do
      described_class.case_permission_changed_for_team(
        investigation:,
        team:,
        user:,
        message:,
        to_email: "test@example.com",
        old_permission:,
        new_permission:
      )
    end

    let(:investigation) { create(:allegation, creator: user) }
    let(:case_type) { "notification" }
    let(:case_title) { investigation.decorate.title }
    let(:user) { create(:user, :activated, name: "Bob Jones") }
    let(:team) { create(:team) }
    let(:old_permission) { "readonly" }
    let(:new_permission) { "edit" }

    context "with a message" do
      let(:message) { "Thanks for collaborating!" }

      it "sets the personalisation" do
        expect_personalisation_to_include_case_attributes
        expect(mail.govuk_notify_personalisation).to include(
          updater_name: "Bob Jones (#{user.team.name})",
          optional_message: "Message from Bob Jones (#{user.team.name}):\n\n^ Thanks for collaborating!",
          old_permission: "view full notification",
          new_permission: "edit full notification"
        )
      end
    end

    context "with no message" do
      let(:message) { nil }

      it "sets the personalisation" do
        expect_personalisation_to_include_case_attributes
        expect(mail.govuk_notify_personalisation).to include(
          updater_name: "Bob Jones (#{user.team.name})",
          optional_message: "",
          old_permission: "view full notification",
          new_permission: "edit full notification"
        )
      end
    end
  end

  # TODO: remove this once all mailers are migrated to use notification param
  def expect_personalisation_to_include_case_attributes
    expect(mail.govuk_notify_personalisation).to include(
      case_type:,
      case_title:,
      case_id: investigation.pretty_id,
    )
  end

  def expect_personalisation_to_include_notification_attributes
    expect(mail.govuk_notify_personalisation).to include(
      case_type:,
      case_title:,
      case_id: notification.pretty_id,
    )
  end
end
