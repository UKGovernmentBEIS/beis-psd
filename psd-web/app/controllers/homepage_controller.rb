class HomepageController < ApplicationController
  skip_before_action :authenticate_user!, only: :landing_page
  skip_before_action :authorize_user, only: :landing_page
  skip_before_action :has_accepted_declaration, only: :landing_page

  def landing_page
    route_user if user_signed_in?
  end

  def show
    route_user
  end

private

  def route_user
    if User.current.is_opss?
      redirect_to investigations_path
    elsif User.current.has_viewed_introduction
      render "non_opss"
    else
      redirect_to introduction_overview_path
    end
  end
end
