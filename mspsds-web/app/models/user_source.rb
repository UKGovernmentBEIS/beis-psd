class UserSource < Source
  belongs_to_active_hash :user, inverse_of: :user_source

  def show
    user.present? ? user.display_name : "anonymous"
  end

  def current_user_has_gdpr_access?
    User.current.organisation == user&.organisation
  end
end
