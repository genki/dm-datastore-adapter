# make sure we're running inside Merb
if defined?(Merb::Plugins)

  # Merb gives you a Merb::Plugins.config hash...feel free to put your stuff in your piece of it
  Merb::Plugins.config[:dm_datastore_adapter] = {
  }
  
  Merb::BootLoader.before_app_loads do
    # require code that must be loaded before the application
    require File.join(%w(dm-datastore-adapter datastore-adapter))
    require File.join(%w(dm-datastore-adapter transaction))
  end
  
  Merb::BootLoader.after_app_loads do
    # code that can be required after the application loads
  end
  
  Merb::Plugins.add_rakefiles "dm-datastore-adapter/merbtasks"
end
