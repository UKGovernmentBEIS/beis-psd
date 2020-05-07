class InviteUserToTeam
  include Interactor

  delegate :email, :user, :team, :inviting_user, to: :context

  def call
    context.fail!(error: "No email or user supplied") unless email || user
    context.fail!(error: "No team supplied") unless team

    unless user
      existing_user = User.find_by email: email
      context.user = existing_user&.team == team ? existing_user : create_user
    end

    send_invite
  end

private

  def create_user
    user = User.create!(
      email: email,
      organisation: team.organisation,
      skip_password_validation: true,
      teams: [team]
    )

    user.user_roles.create!(name: "psd_user") # TODO: remove this once we’ve updated the application to no longer depend upon this role.
    user.user_roles.create!(name: "opss_user") if inviting_user&.is_opss?
    user
  end

  def send_invite
    if !user.invitation_token || (user.invited_at < 1.hour.ago)
      user.update! invitation_token: user.invitation_token || SecureRandom.hex(15), invited_at: Time.current
    end

    SendUserInvitationJob.perform_later(user.id, inviting_user&.id)
  end
end
