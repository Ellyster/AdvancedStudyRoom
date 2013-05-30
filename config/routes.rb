AdvancedStudyRoom::Application.routes.draw do

  devise_for :users, controllers: {registrations: :signup} do
    get  'login',     to: 'devise/sessions#new',        as: 'login'
    post 'login',     to: 'devise/sessions#create'
    get  'logout',    to: 'devise/sessions#destroy',    as: 'logout'
    get  'signup',    to: 'signup#new',                 as: 'signup'
    post 'signup',    to: 'signup#create'
  end

  resources :posts, :pages

  mount Markitup::Rails::Engine, at: "markitup", as: "markitup"

  delete 'events/:id/registrations/:registration_id/quit', to: 'events#quit', as: 'event_registration_quit'
  post 'events/:id/accounts/:account_id/join_other',  to: 'events#join_other', as: 'join_other'

  get 'profile',        to: 'users#profile'
  resources :users do
    get  :profile,      on: :member
    post :toggle_admin, on: :member
    resources :accounts
  end

  get 'results',        to: 'results#main_event'
  get 'no_events',      to: 'results#no_events'

  resources :events do
    get :results, to: 'results#index'
    get :matches, on: :member

    member do
      get     :results
      get     :manage
      get     :overview
      post    :join
      delete  :quit
    end

    resources :tiers
    resources :tags, controller: 'event_tags'
    resources :registrations do
      put :update, on: :collection
      get :matches, on: :member
      put :remove, on: :member
    end
  end

  post  'registrations/:registration_id/matches/download',  to: "matches#download", as: "download_registration_matches"
  post  'matches/:id/validate',   to: "matches#validate",   as: "validate_match"
  post  'matches/:id/check_tags', to: "matches#check_tags", as: "check_match_tags"
  get   'leagues',        to: 'events#leagues'

  put   'validate_games', to: 'events#validate_games'
  put   'tag_games',      to: 'events#tag_games'

  resources :rulesets,
            :divisions

  resources :tiers do
    resources :divisions
    get 'ruleset', to: 'tiers#ruleset'
  end

  resources :pages

  match '/', to: 'pages#home'

  match ':permalink', to: 'pages#show'

  root to: "pages#home"

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
