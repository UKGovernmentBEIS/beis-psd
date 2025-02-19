FactoryBot.define do
  factory :supporting_document_notification, parent: :investigation, class: "Investigation::Notification" do
    association :creator_user, factory: :user
    association :owner_team, factory: :team
    association :creator_team, factory: :team

    # We need to do this before rather than after create because database
    # constraints on pretty_id need to be satisfied
    # Cases created by non OPSS users must have a product assigned to them.
    before(:create) do |investigation, options|
      if investigation.creator_user.is_opss?
        CreateNotification.call(notification: investigation, user: investigation.creator_user)
      else
        CreateNotification.call(notification: investigation, user: investigation.creator_user, product: create(:product))
      end
    end
  end
end
