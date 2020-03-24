module Users
  class SessionsController < Devise::SessionsController
    skip_before_action :has_accepted_declaration
    skip_before_action :has_viewed_introduction

    def new
      super { self.resource = resource.decorate }
    end

    def create
      self.resource = resource_class.new(sign_in_params)

      if sign_in_form.invalid?
        resource.errors.merge!(sign_in_form.errors)

        return render :new
      end

      user = User.find_by(email: sign_in_form.email)
      if user && user.access_locked?
        return redirect_to account_locked_path
      end

      self.resource = warden.authenticate(auth_options)

      # Stop users from signing in if they’ve not completed 2FA verification
      # of their mobile number during account set up process.
      if Rails.configuration.two_factor_authentication_enabled && !resource.mobile_number_verified
        # Need to sign the user out here as they will have been signed in by
        # warden.authenticate(auth_options) above.
        sign_out
        User.current = nil
        resource.errors.add(:email, I18n.t(:wrong_email_or_password, scope: "sign_user_in.email"))
        return render :new
      end

      if resource&.mobile_number?
        sign_in(resource_name, resource)
        return respond_with resource, location: after_sign_in_path_for(resource)
      elsif resource
        return redirect_to missing_mobile_number_path
      end

      self.resource = resource_class.new(sign_in_params).decorate
      resource.errors.add(:email, I18n.t(:wrong_email_or_password, scope: "sign_user_in.email"))
      resource.errors.add(:password, nil)
      render :new
    end

    def account_locked; end

  private

    def sign_in_form
      @sign_in_form ||= SignInForm.new(sign_in_params)
    end
  end
end
