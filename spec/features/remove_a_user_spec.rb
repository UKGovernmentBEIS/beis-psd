require "rails_helper"

RSpec.feature "Removing a user", :with_stubbed_mailer, :with_stubbed_elasticsearch, :with_errors_rendered, type: :feature do
  let(:team) { create(:team) }
  let(:email) { Faker::Internet.safe_email }
  let!(:other_user) { create(:user, :activated, team: team, has_viewed_introduction: true, name: "BBBBB") }

  context "when the user is a team admin" do
    let(:user) { create(:user, :activated, :team_admin, team: team, has_viewed_introduction: true, name: "AAAAA") }

    before do
      sign_in(user)
    end

    context "when user to be removed is activated and not an admin" do
      context "when admin clicks yes to remove user" do
        scenario "user is deleted" do
          visit "/teams/#{team.id}"
          click_link "Remove"

          expect(page.current_path).to eq "/remove_user"

          expect(page).to have_content "Do you want to remove #{other_user.name} from your team"

          choose("Yes")

          click_button("Save and continue")

          expect(page.current_path).to eq "/teams/#{team.id}"
          expect(page).to have_content "The team member was removed"
          expect(page).not_to have_content other_user.name
        end

        context "when admin clicks no to remove user" do
          scenario "user is not deleted" do
            visit "/teams/#{team.id}"
            click_link "Remove"

            expect(page.current_path).to eq "/remove_user"

            expect(page).to have_content "Do you want to remove #{other_user.name} from your team"

            choose("No")

            click_button("Save and continue")

            expect(page.current_path).to eq "/teams/#{team.id}"
            expect(page).to have_content other_user.name
          end
        end
      end

      context "when user to be removed is activated and not an admin" do
        let!(:other_user) { create(:user, team: team, has_viewed_introduction: true, name: "BBBBB") }

        context "when admin clicks yes to remove user" do
          scenario "user is deleted" do
            visit "/teams/#{team.id}"
            click_link "Remove"

            expect(page.current_path).to eq "/remove_user"

            expect(page).to have_content "Do you want to remove #{other_user.name} from your team"

            choose("Yes")

            click_button("Save and continue")

            expect(page.current_path).to eq "/teams/#{team.id}"
            expect(page).to have_content "The team member was removed"
          end
        end
      end
    end

    context "when the user is not a team admin" do
      let(:user) { create(:user, :activated, team: team, has_viewed_introduction: true, name: "AAAAA") }

      scenario "does not allow user to remove other users" do
        visit "/teams/#{team.id}"
        expect(page).not_to have_link "Remove"
      end
    end
  end
end
