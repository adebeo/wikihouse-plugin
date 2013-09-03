require 'extensions.rb'

module WikihouseExtension
  
  path = File.dirname(__FILE__)
  loader = File.join(path, 'wikihouse-extension', 'wikihouse.rb')
  # Define and Load the wikihouse Extension 
  title = 'Wikihouse Plugin Development Version'
  EXTENSION = SketchupExtension.new(title, loader)
  EXTENSION.version     = '0.3.0'
  EXTENSION.copyright   = 'Public Domain - 2013'
  EXTENSION.creator     = 'Wikihouse Development Team'
  EXTENSION.description = 'Allows for the sharing and downloading of ' <<
    'wikihouse models at http://www.wikihouse.cc/, as well as the ' <<
    'translation of models to cutting templates.'
  
  # All constants should be defined before loading extension to avoid error. 
  Sketchup.register_extension(EXTENSION, true)

end # module
