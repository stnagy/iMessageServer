Rails.application.routes.draw do

  root 'application#settings'

  post 'preferences/update' => 'application#update_preferences', :as => :update_preferences
  post 'shortcuts/add' => 'application#add_shortcut', :as => :add_shortcut
  post 'shortcuts/delete' => 'application#delete_shortcut', :as => :delete_shortcut

  get '/settings' => 'application#settings', :as => :settings
  get '/chats' => 'application#chats', :as => :chats
  get '/shortcuts' => 'application#shortcuts', :as => :shortcuts

end
