require "rails_helper"

RSpec.describe Notifications::AddSupportingDocumentsController, :with_stubbed_antivirus, :with_stubbed_mailer, type: :controller do
  let(:creator_user) { create(:user, :activated, :opss_user) }
  let(:owner_user) { create(:user, :activated, :opss_user) }
  let(:other_user) { create(:user, :activated, :opss_user) }
  let(:creator_team) { create(:team) }
  let(:owner_team) { create(:team) }
  let(:edit_access_team) { create(:team) }
  let(:read_only_team) { create(:team) }
  let(:notification) do
    create(:supporting_document_notification,
           creator_user: creator_user,
           creator_team: creator_team,
           owner_user: owner_user,
           owner_team: owner_team)
  end
  let(:document) { fixture_file_upload("testImage.png", "image/png") }
  let(:policy) { instance_double(InvestigationPolicy, update?: true, view_non_protected_details?: true) }
  let(:mailer) { instance_double(ActionMailer::MessageDelivery, deliver_later: true) }
  let(:valid_params) do
    {
      notification_pretty_id: notification.pretty_id,
      document_form: {
        document: fixture_file_upload("testImage.png", "image/png"),
        title: "Test"
      }
    }
  end
  let(:invalid_params) do
    {
      notification_pretty_id: notification.pretty_id,
      document_form: {
        document: nil,
        title: ""
      }
    }
  end

  before do
    notification.teams_with_edit_access << edit_access_team
    notification.teams_with_read_only_access << read_only_team
    sign_in(creator_user)
    allow(notification).to receive(:is_closed?).and_return(false)
    allow(NotifyMailer).to receive(:notification_created).and_return(mailer)
    allow(InvestigationPolicy).to receive(:new).and_return(policy)
  end

  shared_examples "forbidden access" do
    before do
      allow(policy).to receive_messages(update?: false, view_non_protected_details?: false)
    end

    it "returns forbidden status" do
      get :show, params: { notification_pretty_id: notification.pretty_id }
      expect(response).to have_http_status(:forbidden)
    end

    it "prevents document upload" do
      expect {
        post :update, params: valid_params
      }.not_to(change { notification.documents.count })
    end

    it "prevents document removal" do
      notification.documents.attach(document)
      document_id = notification.documents.first.id

      expect {
        delete :remove_upload, params: { notification_pretty_id: notification.pretty_id, upload_id: document_id }
      }.not_to(change { notification.documents.count })
    end
  end

  shared_examples "allowed access" do
    before do
      allow(policy).to receive_messages(update?: true, view_non_protected_details?: true)
    end

    it "allows viewing the form" do
      get :show, params: { notification_pretty_id: notification.pretty_id }
      expect(response).to render_template("add_supporting_documents")
    end

    it "allows document upload" do
      expect {
        post :update, params: valid_params
      }.to change { notification.documents.count }.by(1)
    end

    it "allows document removal" do
      notification.documents.attach(document)
      document_id = notification.documents.first.id

      expect {
        delete :remove_upload, params: { notification_pretty_id: notification.pretty_id, upload_id: document_id }
      }.to change { notification.documents.count }.by(-1)
    end
  end

  context "when notification is open" do
    before do
      allow(notification).to receive(:is_closed?).and_return(false)
    end

    context "when user is the creator" do
      include_examples "allowed access"
    end

    context "when user is the owner" do
      before { sign_in(owner_user) }

      include_examples "allowed access"
    end

    context "when user is in the creator team" do
      before { sign_in(create(:user, :activated, team: creator_team)) }

      include_examples "allowed access"
    end

    context "when user is in the owner team" do
      before { sign_in(create(:user, :activated, team: owner_team)) }

      include_examples "allowed access"
    end

    context "when user is in a team with edit access" do
      before { sign_in(create(:user, :activated, team: edit_access_team)) }

      include_examples "allowed access"
    end

    context "when user is in a team with read-only access" do
      before { sign_in(create(:user, :activated, team: read_only_team)) }

      include_examples "forbidden access"
    end

    context "when user has no access" do
      before { sign_in(other_user) }

      include_examples "forbidden access"
    end
  end

  context "when notification is closed" do
    before do
      allow(notification).to receive(:is_closed?).and_return(true)
    end

    context "when user is the creator" do
      include_examples "forbidden access"
    end

    context "when user is the owner" do
      before { sign_in(owner_user) }

      include_examples "forbidden access"
    end

    context "when user is in a team with edit access" do
      before { sign_in(create(:user, :activated, team: edit_access_team)) }

      include_examples "forbidden access"
    end
  end

  context "with invalid notification ID" do
    it "returns 404 status" do
      get :show, params: { notification_pretty_id: "nonexistent" }
      expect(response).to have_http_status(:not_found)
    end
  end

  context "when user is not signed in" do
    before { sign_out(creator_user) }

    it "redirects to sign in page" do
      get :show, params: { notification_pretty_id: notification.pretty_id }
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
