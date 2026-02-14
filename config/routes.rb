Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[ new create ]
  resources :passwords, param: :token
  resources :api_keys, only: %i[ index create update destroy ]
  resources :map_styles, only: %i[ index create destroy ]

  resources :maps do
    resources :markers, except: %i[ index show ]
  end

  get "embed/:token", to: "embeds#show", as: :embed
  get "dashboard", to: "dashboard#index", as: :dashboard

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"
end
