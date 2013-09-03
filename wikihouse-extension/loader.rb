module WikiHouseExtension

	SUPPORT_PATH 		 = File.join(File.dirname(__FILE__))
	LIB_PATH 				 = File.join(SUPPORT_PATH, 'lib')
	WIKIHOUSE_ASSETS = File.join(SUPPORT_PATH, 'wikihouse-assets')

	path = File.dirname(__FILE__)
	lib_path = File.join(path, 'lib')

	Sketchup::require File.join(lib_path, 'utils.rb')
	Sketchup::require File.join(lib_path, 'core.rb')

	Sketchup::require File.join(lib_path, 'JSON.rb')
	Sketchup::require File.join(lib_path, 'WebDialog.rb')

	Sketchup::require File.join(lib_path, 'wh_entities.rb')
	Sketchup::require File.join(lib_path, 'wh_layout_engine.rb')
	Sketchup::require File.join(lib_path, 'wh_panel.rb')

	Sketchup::require File.join(lib_path, 'writer.rb')
	Sketchup::require File.join(lib_path, 'writer_dxf.rb')
	Sketchup::require File.join(lib_path, 'writer_svg.rb')

	Sketchup::require File.join(lib_path, 'wikihouse.rb')
end # module
