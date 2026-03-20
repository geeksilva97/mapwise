Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[ new create ]
  resources :passwords, param: :token

  get "email_verification/:token", to: "email_verifications#show", as: :email_verification
  post "email_verification/resend", to: "email_verifications#create", as: :resend_email_verification
  resource :settings, only: %i[ show update ], controller: "settings"
  resources :api_keys, only: %i[ create update destroy ]
  resources :map_styles, only: %i[ create destroy ]

  resources :workspaces, except: [ :index ] do
    member { post :switch }
    resources :memberships, only: [ :create, :update, :destroy ]
  end

  resources :maps do
    resources :markers, except: %i[ index show ] do
      member { patch :ungroup }
    end
    resources :marker_groups, only: %i[ create update destroy ] do
      member { patch :toggle_visibility; patch :assign_markers }
    end
    resources :imports, only: %i[ create show update ]
    resources :layers, only: %i[ create update destroy ] do
      member { patch :toggle_visibility }
    end
    resources :tracked_vehicles, except: [ :show ] do
      member do
        patch :toggle_active
        delete :clear_points
        patch :save_planned_path
        get :points
      end
    end
    resources :deviation_alerts, only: [] do
      member { patch :acknowledge }
    end
    resources :chat_messages, only: [ :create ] do
      collection { delete :clear }
    end
    member { get :tracking }
  end

  post "webhooks/tracking/:token", to: "webhooks#tracking", as: :webhook_tracking

  get "embed/:token", to: "embeds#show", as: :embed
  get "dashboard", to: "dashboard#index", as: :dashboard

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"
end
