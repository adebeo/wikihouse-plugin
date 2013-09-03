module WikiHouseExtension

  # ----------------------------------------------------------------------------
  # Development Configuration

  WIKIHOUSE_DEV   = true
  WIKIHOUSE_LOCAL = false 
  WIKIHOUSE_HIDE  = false  
  WIKIHOUSE_SHORT_CIRCUIT = false

  # ----------------------------------------------------------------------------
  # General

  WIKIHOUSE_TITLE = 'WikiHouse'

  PANEL_ID_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  PANEL_ID_ALPHABET_LENGTH = PANEL_ID_ALPHABET.length
  
  # ----------------------------------------------------------------------------
  # Paths

  if WIKIHOUSE_LOCAL
    WIKIHOUSE_SERVER = 'http://localhost:8080'
  else
    WIKIHOUSE_SERVER = 'http://wikihouse-cc.appspot.com'
  end
  
  WIKIHOUSE_DOWNLOAD_PATH = '/library/sketchup'
  WIKIHOUSE_UPLOAD_PATH   = '/library/designs/add/sketchup'
  WIKIHOUSE_DOWNLOAD_URL  = WIKIHOUSE_SERVER + WIKIHOUSE_DOWNLOAD_PATH
  WIKIHOUSE_UPLOAD_URL    = WIKIHOUSE_SERVER + WIKIHOUSE_UPLOAD_PATH
  
  WIKIHOUSE_TEMP = get_temp_directory()
  
  # Get Platform
  if RUBY_PLATFORM =~ /mswin/
    WIKIHOUSE_CONF_FILE = File.join(ENV['APPDATA'], 'WikiHouse.conf')
    WIKIHOUSE_SAVE = get_documents_directory(ENV['USERPROFILE'], 'Documents')
    WIKIHOUSE_MAC = false
  else
    WIKIHOUSE_CONF_FILE = File.join(ENV['HOME'], '.wikihouse.conf')
    WIKIHOUSE_SAVE = get_documents_directory(ENV['HOME'], 'Documents')
    WIKIHOUSE_MAC = true
  end

  # ----------------------------------------------------------------------------
  # Settings
  
  # Set WikiHouse Panel Dimensions
  wikihouse_sheet_height  = 1200.mm
  wikihouse_sheet_width   = 2400.mm
  wikihouse_sheet_depth   = 18.mm
  wikihouse_panel_padding = 25.mm / 2
  wikihouse_sheet_margin  = 15.mm - wikihouse_panel_padding
  wikihouse_font_height   = 30.mm
  wikihouse_sheet_inner_height = wikihouse_sheet_height - (2 * wikihouse_sheet_margin)
  wikihouse_sheet_inner_width  = wikihouse_sheet_width - (2 * wikihouse_sheet_margin)
  
  # Store the actual values as length objects (in inches)
  @settings = {
    'sheet_height'       => wikihouse_sheet_height,
    'sheet_inner_height' => wikihouse_sheet_inner_height,
    'sheet_width'        => wikihouse_sheet_width, 
    'sheet_inner_width'  => wikihouse_sheet_inner_width,
    'sheet_depth'        => wikihouse_sheet_depth, 
    'padding'            => wikihouse_panel_padding,
    'margin'             => wikihouse_sheet_margin,
    'font_height'        => wikihouse_font_height,
  }

  class << self
    attr_accessor :settings
  end

  # Store default values for resetting.
  DEFAULT_SETTINGS = Hash[@settings]

  # ----------------------------------------------------------------------------
  # UI Configuration

  unless file_loaded?(__FILE__)

    # Initialise the data containers.
    WIKIHOUSE_DOWNLOADS = Hash.new
    WIKIHOUSE_UPLOADS = Hash.new

    # Initialise the downloads counter.
    @downloads_id = 0
    class << self
      attr_accessor :downloads_id
    end

    # Initialise the core commands.
    WIKIHOUSE_DOWNLOAD = UI::Command.new("Get Models...") {
      self.load_wikihouse_download
    }
    
    WIKIHOUSE_DOWNLOAD.tooltip = "Find new models to use at #{WIKIHOUSE_TITLE}"
    WIKIHOUSE_DOWNLOAD.small_icon = File.join(WIKIHOUSE_ASSETS, 'download-16.png')
    WIKIHOUSE_DOWNLOAD.large_icon = File.join(WIKIHOUSE_ASSETS, 'download.png')

    # TODO(tav): Irregardless of these procs, all commands seem to get greyed
    # out when no models are open -- at least on OSX.
    WIKIHOUSE_DOWNLOAD.set_validation_proc {
      MF_ENABLED
    }

    WIKIHOUSE_MAKE = UI::Command.new('Make This House...') {
      self.load_wikihouse_make
    }

    WIKIHOUSE_MAKE.tooltip = 'Convert a model of a House into printable components'
    WIKIHOUSE_MAKE.small_icon = File.join WIKIHOUSE_ASSETS, 'make-16.png'
    WIKIHOUSE_MAKE.large_icon = File.join WIKIHOUSE_ASSETS, 'make.png'
    WIKIHOUSE_MAKE.set_validation_proc {
      if Sketchup.active_model
        MF_ENABLED
      else
        MF_DISABLED | MF_GRAYED
      end
    }
    
    WIKIHOUSE_UPLOAD = UI::Command.new("Share Model...") {
      self.load_wikihouse_upload
    }

    WIKIHOUSE_UPLOAD.tooltip = "Upload and share your model at #{WIKIHOUSE_TITLE}"
    WIKIHOUSE_UPLOAD.small_icon = File.join(WIKIHOUSE_ASSETS, 'upload-16.png')
    WIKIHOUSE_UPLOAD.large_icon = File.join(WIKIHOUSE_ASSETS, 'upload.png')
    WIKIHOUSE_UPLOAD.set_validation_proc {
      if Sketchup.active_model
        MF_ENABLED
      else
        MF_DISABLED|MF_GRAYED
      end
    }
    
    WIKIHOUSE_SETTINGS = UI::Command.new('Settings...') {
      self.load_wikihouse_settings
    }

    WIKIHOUSE_SETTINGS.tooltip = "Change #{WIKIHOUSE_TITLE} settings"
    WIKIHOUSE_SETTINGS.small_icon = File.join(WIKIHOUSE_ASSETS, 'cog-16.png')
    WIKIHOUSE_SETTINGS.large_icon = File.join(WIKIHOUSE_ASSETS, 'cog.png')
    WIKIHOUSE_SETTINGS.set_validation_proc {
      MF_ENABLED
    }
    

    # Register a new toolbar with the commands.
    WIKIHOUSE_TOOLBAR = UI::Toolbar.new(WIKIHOUSE_TITLE)
    WIKIHOUSE_TOOLBAR.add_item(WIKIHOUSE_DOWNLOAD)
    WIKIHOUSE_TOOLBAR.add_item(WIKIHOUSE_UPLOAD)
    WIKIHOUSE_TOOLBAR.add_item(WIKIHOUSE_MAKE)
    WIKIHOUSE_TOOLBAR.add_item(WIKIHOUSE_SETTINGS)
    WIKIHOUSE_TOOLBAR.show

    # Register a new submenu of the standard Plugins menu with the commands.
    WIKIHOUSE_MENU = UI.menu('Plugins').add_submenu(WIKIHOUSE_TITLE)
    WIKIHOUSE_MENU.add_item(WIKIHOUSE_DOWNLOAD)
    WIKIHOUSE_MENU.add_item(WIKIHOUSE_UPLOAD)
    WIKIHOUSE_MENU.add_item(WIKIHOUSE_MAKE)
    WIKIHOUSE_MENU.add_item(WIKIHOUSE_SETTINGS)

    # Add our custom AppObserver.
    Sketchup.add_observer(WikiHouseAppObserver.new)

  end # if file_loaded?

end # module


# ------------------------------------------------------------------------------
# Debug

# Display the Ruby Console in dev mode.
if WikiHouseExtension::WIKIHOUSE_DEV && !file_loaded?(__FILE__)
  Sketchup.send_action('showRubyPanel:')
  
  puts ""
  puts "#{WikiHouseExtension::WIKIHOUSE_TITLE} Extension Successfully Loaded."
  puts ""
  
  # Interactive utilities
  def mod
    return Sketchup.active_model
  end
  def ent
    return Sketchup.active_model.entities
  end
  def sel 
    return Sketchup.active_model.selection
  end
end


file_loaded(__FILE__)
