lib_path = File.dirname(__FILE__)
require File.join(lib_path, 'utils.rb')

module WikiHouseExtension

  # Run Flags
  WIKIHOUSE_DEV = true   # If true brings up Ruby Console and loads some utility functions on startup
  WIKIHOUSE_LOCAL = false 
  WIKIHOUSE_HIDE = false  
  WIKIHOUSE_SHORT_CIRCUIT = false

  # Some Global Constants
  WIKIHOUSE_TITLE = 'WikiHouse'
  # Panel stuff
  PANEL_ID_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  PANEL_ID_ALPHABET_LENGTH = PANEL_ID_ALPHABET.length
  
  # Path setup 
  if WIKIHOUSE_LOCAL
    WIKIHOUSE_SERVER = "http://localhost:8080"
  else
    WIKIHOUSE_SERVER = "http://wikihouse-cc.appspot.com"
  end

  LIB_PATH = File.join(File.dirname(__FILE__))
  
  WIKIHOUSE_DOWNLOAD_PATH = "/library/sketchup"
  WIKIHOUSE_UPLOAD_PATH = "/library/designs/add/sketchup"
  WIKIHOUSE_DOWNLOAD_URL = WIKIHOUSE_SERVER + WIKIHOUSE_DOWNLOAD_PATH
  WIKIHOUSE_UPLOAD_URL = WIKIHOUSE_SERVER + WIKIHOUSE_UPLOAD_PATH
  
  WIKIHOUSE_TEMP = get_temp_directory
  
  # Get Platform
  if RUBY_PLATFORM =~ /mswin/
    WIKIHOUSE_CONF_FILE = File.join ENV['APPDATA'], 'WikiHouse.conf'
    WIKIHOUSE_SAVE = get_documents_directory ENV['USERPROFILE'], 'Documents'
    WIKIHOUSE_MAC = false
  else
    WIKIHOUSE_CONF_FILE = File.join ENV['HOME'], '.wikihouse.conf'
    WIKIHOUSE_SAVE = get_documents_directory ENV['HOME'], 'Documents'
    WIKIHOUSE_MAC = true
  end
  
  # Set defaults for Global Variables 
  
  # Set Wikihouse Pannel Dimentions
  wikihouse_sheet_height = 1200.mm
  wikihouse_sheet_width = 2400.mm
  wikihouse_sheet_depth = 18.mm
  wikihouse_panel_padding = 25.mm / 2
  wikihouse_sheet_margin = 15.mm - wikihouse_panel_padding
  wikihouse_font_height = 30.mm
  wikihouse_sheet_inner_height = wikihouse_sheet_height - (2 * wikihouse_sheet_margin)
  wikihouse_sheet_inner_width = wikihouse_sheet_width - (2 * wikihouse_sheet_margin)
  
  #(Chris) Plan to eventually store all setting as a hash. 
  
  # Store the actual values as length objects (in inches)
  @settings = {
  "sheet_height" => wikihouse_sheet_height,
  "sheet_inner_height" => wikihouse_sheet_inner_height,
  "sheet_width"  => wikihouse_sheet_width, 
  "sheet_inner_width"  => wikihouse_sheet_inner_width,
  "sheet_depth" => wikihouse_sheet_depth, 
  "padding"      => wikihouse_panel_padding,
  "margin"       => wikihouse_sheet_margin,
  "font_height"  => wikihouse_font_height,
  }
  
  # Store default values for recall
  DEFAULT_SETTINGS = Hash[@settings]
  
  def self.settings
   @settings
  end
  def self.settings=(settings)
   @settings = settings
  end

end