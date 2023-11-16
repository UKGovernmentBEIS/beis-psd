SupportPortal::Engine.routes.draw do
  root "dashboard#index", as: :support_root

  resources :account_administration, path: "account-admin", only: %i[index show] do
    collection do
      get "search"
      get "search-results"
      get "invite-user"
      patch "create-user"
      put "create-user"
    end

    member do
      get "edit-name"
      patch "update-name"
      put "update-name"
      get "edit-email"
      patch "update-email"
      put "update-email"
      get "edit-mobile-number"
      patch "update-mobile-number"
      put "update-mobile-number"
      get "edit-team-admin-role"
      patch "update-team-admin-role"
      put "update-team-admin-role"
      get "remove-user"
      delete "delete-user"
    end
  end

  resources :history, only: %i[index]
end
