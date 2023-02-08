Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"

  root "api#pocetak"
  post '/api/update_user', to: 'api#updateUser'
  post '/api/update_user1', to: 'api#updateUser1'
  get '/api/slika/:id', to: 'api#slika'
  post '/api/predvorje', to: 'api#predvorje'
  post '/api/soba', to: 'api#stanjeSobe'
  post '/api/room_enter_exit', to: 'api#roomEnterExit'

  post '/api/signin', to: 'api#signin'
  post '/api/signup', to: 'api#signup'
  post '/api/signout', to: 'api#signout'
  post '/api/refresh_token', to: 'api#refreshToken'
  post '/api/provjeri_token', to: 'api#provjeriToken'
  post '/api/zasticena', to: 'api#zasticena'
end
