Rails.application.routes.draw do

  root 'application#home'
  post 'preferences/update' => 'application#update_preferences', :as => :update_preferences

end
