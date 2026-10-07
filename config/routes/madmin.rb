# Below are the routes for madmin
namespace :madmin do
  namespace :active_storage do
    resources :variant_records
  end
  namespace :active_storage do
    resources :attachments
  end
  namespace :active_storage do
    resources :blobs
  end
  resources :clients
  resources :services
  resources :stylists
  resources :admin_users
  resources :appointments
  resources :appointment_services
  resources :categories
  root to: "dashboard#show"
end
