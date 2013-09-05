require 'sketchup.rb'
require 'extensions.rb'

module WikiHouseExtension
  
  path = File.dirname(__FILE__)
  loader = File.join(path, 'wikihouse-extension', 'loader.rb')
  
  title = 'WikiHouse Plugin Development Version'
  EXTENSION = SketchupExtension.new(title, loader)
  EXTENSION.version     = '0.3.1'
  EXTENSION.copyright   = 'Public Domain - 2013'
  EXTENSION.creator     = 'WikiHouse Development Team'
  EXTENSION.description = 'Allows for the sharing and downloading of ' <<
    'WikiHouse models at http://www.wikihouse.cc/, as well as the ' <<
    'translation of models to cutting templates.'
  
  # All constants should be defined before loading extension to avoid error. 
  Sketchup.register_extension(EXTENSION, true)

end # module
