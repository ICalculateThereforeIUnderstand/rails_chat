Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"

  root "api#pocetak"
  post '/api/update_user', to: 'api#updateUser'
  post '/api/predvorje', to: 'api#predvorje'

  post '/api/signin', to: 'api#signin'
  post '/api/signup', to: 'api#signup'
  post '/api/signout', to: 'api#signout'
  post '/api/refresh_token', to: 'api#refreshToken'
  post '/api/zasticena', to: 'api#zasticena'
end
