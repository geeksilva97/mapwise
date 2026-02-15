Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[ new create ]
  resources :passwords, param: :token
  resources :api_keys, only: %i[ index create update destroy ]
  resources :map_styles, only: %i[ index create destroy ]

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
    resources :tracked_vehicles, except: [:show] do
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
    member { get :tracking }
  end

  post "webhooks/tracking/:token", to: "webhooks#tracking", as: :webhook_tracking

  get "embed/:token", to: "embeds#show", as: :embed
  get "dashboard", to: "dashboard#index", as: :dashboard

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"
end
