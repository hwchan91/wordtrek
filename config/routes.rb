Rails.application.routes.draw do
  get 'users/update'

  root to: 'levels#home'
  resources :levels, only: [:show, :index] do
    member do
      get "move"
      get "reset"
      get "undo"
      get "skip_zen_level"
      get "loading"
      get "get_hints"
    end
  end
  resources :users, only: [:update]
end
