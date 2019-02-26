require 'rails_helper'

RSpec.describe "Responsible person dashboard", type: :system do
  let(:responsible_person_1) { create(:responsible_person_with_user) }
  let(:responsible_person_2) { create(:responsible_person, email_address: "responsible_person_2@example.com") }
  let(:user_1) { responsible_person_1.responsible_person_users.first.user }
  let(:user_2) { create(:user) }

  before do
    sign_in as_user: user_1
  end

  after do
    sign_out
  end

  it "only shows user the erroneous notifications belonging to their Responsible Person" do
    create(:notification_file, responsible_person: responsible_person_1, user: user_1,
           upload_error: "uploaded_file_not_a_zip")
    create(:notification_file, responsible_person: responsible_person_2,
                                                              upload_error: "uploaded_file_not_a_zip")
    visit responsible_person_notifications_path(responsible_person_1)
    assert_text "Errors (1)"
  end

  it "only shows user the unfinished notifications belonging to their Responsible Person" do
    create(:draft_notification, responsible_person: responsible_person_1)
    create(:draft_notification, responsible_person: responsible_person_2)
    visit responsible_person_notifications_path(responsible_person_1)
    assert_text "Unfinished (1)"
  end

  it "only shows user the registered notifications belonging to their Responsible Person" do
    create(:registered_notification, responsible_person: responsible_person_1)
    create(:registered_notification, responsible_person: responsible_person_2)
    visit responsible_person_notifications_path(responsible_person_1)
    assert_text "Registered (1)"
  end

  it "doesn't count number of loading files from other users in Responsible Person" do
    responsible_person_1.add_user(user_2)
    create(:notification_file, responsible_person: responsible_person_1, user: user_1)
    create(:notification_file, responsible_person: responsible_person_1, user: user_2)
    visit responsible_person_notifications_path(responsible_person_1)
    assert_text "Checking 1 notification file"
  end

  it "doesn't count number of loading files from users outside of Responsible Person" do
    responsible_person_2.add_user(user_2)
    create(:notification_file, responsible_person: responsible_person_1, user: user_1)
    create(:notification_file, responsible_person: responsible_person_2, user: user_2)
    visit responsible_person_notifications_path(responsible_person_1)
    assert_text "Checking 1 notification file"
  end

  it "doesn't include erroneous notification files in count for loading files" do
    create(:notification_file, responsible_person: responsible_person_1, user: user_1,
           upload_error: "uploaded_file_not_a_zip")
    create(:notification_file, responsible_person: responsible_person_1, user: user_1)
    visit responsible_person_notifications_path(responsible_person_1)
    assert_text "Checking 1 notification file"
  end

  it "uses pagination to display erroneous notifications" do
    create_list(:notification_file, 11, responsible_person: responsible_person_1, user: user_1,
          upload_error: "uploaded_file_not_a_zip")
    visit responsible_person_notifications_path(responsible_person_1)
    assert_text "Previous 1 2 Next"
  end

  it "uses pagination to display unfinished notifications" do
    create_list(:draft_notification, 11, responsible_person: responsible_person_1)
    visit responsible_person_notifications_path(responsible_person_1)
    assert_text "Previous 1 2 Next"
  end

  it "uses pagination to display registered notifications" do
    create_list(:registered_notification, 11, responsible_person: responsible_person_1)
    visit responsible_person_notifications_path(responsible_person_1)
    assert_text "Previous 1 2 Next"
  end

  it "only dismisses all erroneous notifications for the current user" do
    create_list(:notification_file, 11, responsible_person: responsible_person_1, user: user_1,
                upload_error: "uploaded_file_not_a_zip")
    responsible_person_1.add_user(user_2)
    create_list(:notification_file, 11, responsible_person: responsible_person_1, user: user_2,
                upload_error: "uploaded_file_not_a_zip")
    visit responsible_person_notifications_path(responsible_person_1)
    click_button "Dismiss all failed files"
    sign_out
    sign_in as_user: user_2
    visit responsible_person_notifications_path(responsible_person_1)
    assert_text "Errors (11)"
  end

  it "correctly dismisses a single erroneous notification" do
    create(:notification_file, responsible_person: responsible_person_1, user: user_1,
           upload_error: "uploaded_file_not_a_zip")
    visit responsible_person_notifications_path(responsible_person_1)
    click_button "Dismiss"
    assert_text "Errors (0)"
  end
end
