Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dugout#index"

  get 'leagues/new' => 'leagues#new', as: :new_league
  post 'leagues' => 'leagues#create'
  get 'leagues/:slug' => 'leagues#show', as: :league
  get 'series/:slug' => 'series#show', as: :series
  post 'leagues/:slug/series' => 'series#create', as: :league_series
  post 'series/:slug/refresh' => 'series#refresh', as: :refresh_series
  get 'competitions/:slug' => 'competitions#show', as: :competition
  get 'coaches/:slug' => 'coaches#show', as: :coach
  get 'teams/:slug' => 'teams#show', as: :team
  post 'teams/:slug/refresh' => 'teams#refresh', as: :refresh_team
  get 'matches/:id' => 'matches#show', as: :match
  get 'matches/:id/replay' => 'matches#replay', as: :match_replay
  post 'matches/:id/upload_replay' => 'matches#upload_replay', as: :upload_replay_match
  post 'matches/:id/parse_replay' => 'matches#parse_replay', as: :parse_replay_match
  post 'leagues/:slug/refresh' => 'leagues#refresh', as: :refresh_league
  post 'competitions/:slug/refresh' => 'competitions#refresh', as: :refresh_competition
  post 'competitions/:slug/add_to_series' => 'competitions#add_to_series', as: :add_competition_to_series
end
