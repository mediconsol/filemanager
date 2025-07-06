Rails.application.routes.draw do
  resources :categories
  resources :standard_fields
  resources :etl_pipeline, only: [:index, :show] do
    member do
      post :start_pipeline
      get :status
      post :cancel_jobs
    end
  end

  resources :etl_jobs, only: [] do
    member do
      post :retry_job
    end
  end
  # Temporarily disable devise routes to prevent redirects
  # devise_for :users

  # Manual devise routes for testing
  get '/users/sign_in', to: 'application#welcome'
  get '/users/sign_up', to: 'application#welcome'
  post '/users/sign_in', to: 'application#welcome'
  post '/users', to: 'application#welcome'

  # Root route - main index page
  root "index#show"

  # Backup routes
  get '/welcome', to: 'application#welcome'

  # Index routes
  resources :index, only: [:show]

  # Home routes
  resources :home, only: [:index]

  # Main application routes - all accessible without authentication
  resources :dashboard, only: [:index]
  get '/dashboard', to: 'dashboard#index'  # Explicit route

  # Additional menu routes
  get '/data_upload', to: 'application#welcome'
  get '/analysis', to: 'application#welcome'
  get '/reports', to: 'application#welcome'
  get '/admin', to: 'application#welcome'
  get '/settings', to: 'application#welcome'

  # Temporarily disable complex routes to prevent errors
  # resources :data_uploads do
  #   member do
  #     post :process_data
  #     get :progress
  #   end
  # end

  # resources :mapping_manager, path: 'mapping' do
  #   member do
  #     post :save_mapping
  #     get :preview
  #   end
  end

  resources :analysis_explorer, path: 'analysis' do
    collection do
      post :create_analysis
      get :get_data
      post :save_analysis
    end
    member do
      post :duplicate
    end
  end

  resources :report_scheduler, path: 'reports' do
    member do
      patch :activate
      patch :deactivate
      post :execute_now
    end
  end

  get '/downloads/reports/:execution_id', to: 'report_scheduler#download_report', as: 'download_report'

  # Admin routes
  get '/admin', to: 'admin_center#index', as: 'admin_center'
  get '/admin/system_monitoring', to: 'admin_center#system_monitoring', as: 'admin_system_monitoring'

  namespace :admin_center, path: 'admin' do
    resources :users do
      member do
        patch :activate
        patch :deactivate
        post :reset_password
      end
      collection do
        post :bulk_action
      end
    end

    resources :hospitals do
      member do
        patch :activate
        patch :deactivate
        get :data_summary
      end
      collection do
        post :bulk_action
      end
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA routes
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
