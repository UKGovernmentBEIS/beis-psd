class PoisonCentreNotificationPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all if user.poison_centre_user?
    end
  end

  def index?
    user.poison_centre_user?
  end

  def show?
    user.poison_centre_user?
  end
end
