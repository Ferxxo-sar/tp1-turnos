Rails.application.routes.draw do
  draw :madmin
  get "up" => "rails/health#show", as: :rails_health_check

  # Portal público y de clientes
  root "home#index"
  get "profesionales/:id" => "home#stylist", as: :public_stylist

  get "ingresar" => "sessions#new", as: :login
  post "ingresar" => "sessions#create"
  delete "salir" => "sessions#destroy", as: :logout
  get "registro" => "registrations#new", as: :signup
  post "registro" => "registrations#create"

  resources :appointments, path: "mis-turnos", only: %i[index new create show] do
    patch :cancel, on: :member
  end

  # Back-office
  namespace :admin do
    root "dashboard#index"
    get "ingresar" => "sessions#new", as: :login
    post "ingresar" => "sessions#create"
    delete "salir" => "sessions#destroy", as: :logout

    get "agenda" => "agenda#show", as: :agenda
    get "reportes" => "reports#show", as: :reports

    resources :appointments, path: "turnos"
    resources :stylists, path: "profesionales"
    resources :services, path: "servicios", except: :show
    resources :categories, path: "categorias", except: :show
    resources :clients, path: "clientes"
    resources :admin_users, path: "administradores", except: :show
  end

  # API JSON
  namespace :api do
    namespace :v1 do
      post "login" => "sessions#create"
      delete "logout" => "sessions#destroy"

      resources :categories, only: %i[index show]
      resources :services, only: %i[index show]
      resources :stylists, only: %i[index show] do
        get :availability, on: :member
      end
      resources :appointments, only: %i[index show create] do
        patch :cancel, on: :member
      end
    end
  end
end
