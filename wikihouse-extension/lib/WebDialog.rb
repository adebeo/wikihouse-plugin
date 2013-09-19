# Web Dialogues

module WikiHouseExtension

  # ------------------------------------------------------------------------------
  # Common Callbacks
  # ------------------------------------------------------------------------------
  
  # Download Callback
  # -----------------
  def self.wikihouse_download_callback(dialog, params)
    # Exit if the download parameters weren't set.
    if params == ""
      show_wikihouse_error "Couldn't find the #{WIKIHOUSE_TITLE} model name and url"
      return
    end

    is_comp, base64_url, blob_url, name = params.split ",", 4
    model = Sketchup.active_model

    # Try and save the model/component directly into the current model.
    if model and is_comp == '1'
      reply = UI.messagebox("Load this directly into your SketchUp model?", MB_YESNOCANCEL)
      if reply == IDYES
        loader = WikiHouseLoader.new name
        blob_url = WIKIHOUSE_SERVER + blob_url
        model.definitions.load_from_url blob_url, loader
        if not loader.error
          dialog.close
          UI.messagebox "Successfully downloaded #{name}"
          component = model.definitions[-1]
          if component
            model.place_component component
          end
          return
        else
          UI.messagebox loader.error
          reply = UI.messagebox "Would you like to save the model file instead?", MB_YESNO
          if reply == IDNO
            return
          end
        end
      elsif reply == IDNO
        # Skip through to saving the file directly.
      else
        return
      end
    end

    # Otherwise, get the filename to save into.
    filename = UI.savepanel "Save Model", WIKIHOUSE_SAVE, "#{name}.skp"
    if not filename
      show_wikihouse_error "No filename specified to save the #{WIKIHOUSE_TITLE} model. Please try again."
      return
    end

    # TODO(tav): Ensure that this is atomic and free of thread-related
    # concurrency issues.
    WikiHouseExtension.downloads_id += 1
    download_id = WikiHouseExtension.downloads_id.to_s

    WIKIHOUSE_DOWNLOADS[download_id] = filename

    # Initiate the download.
    dialog.execute_script "wikihouse.download('#{download_id}', '#{base64_url}');"
  end

  # Save Callback
  # -------------
  def self.wikihouse_save_callback(dialog, download_id)
    errmsg = "Couldn't find the #{WIKIHOUSE_TITLE} model data to save"

    # Exit if the save parameters weren't set.
    if download_id == ""
      show_wikihouse_error errmsg
      return
    end

    if not WIKIHOUSE_DOWNLOADS.key? download_id
      show_wikihouse_error errmsg
      return
    end

    filename = WIKIHOUSE_DOWNLOADS[download_id]
    WIKIHOUSE_DOWNLOADS.delete download_id

    segment_count = dialog.get_element_value "design-download-data"
    dialog.close

    if segment_count == ""
      show_wikihouse_error errmsg
      return
    end

    data = []
    for i in 0...segment_count.to_i
      segment = dialog.get_element_value "design-download-data-#{i}"
      if segment == ""
        show_wikihouse_error errmsg
        return
      end
      data << segment
    end

    # Decode the base64-encoded data.
    data = data.join('').unpack("m")[0]
    if data == ""
      show_wikihouse_error errmsg
      return
    end

    # Save the data to the local file.
    File.open(filename, 'wb') do |io|
      io.write data
    end

    reply = UI.messagebox "Successfully saved #{WIKIHOUSE_TITLE} model. Would you like to open it?", MB_YESNO
    if reply == IDYES
      if not Sketchup.open_file filename
        show_wikihouse_error "Couldn't open #{filename}"
      end
    end
  end

  # Error Callback
  # --------------
  def self.wikihouse_error_callback(dialog, download_id)
    if not WIKIHOUSE_DOWNLOADS.key? download_id
      return
    end

    filename = WIKIHOUSE_DOWNLOADS[download_id]
    WIKIHOUSE_DOWNLOADS.delete download_id

    show_wikihouse_error "Couldn't download #{filename} from #{WIKIHOUSE_TITLE}. Please try again."
  end

  # ------------------------------------------------------------------------------
  # Download Web Dialogue
  # ------------------------------------------------------------------------------
  def self.load_wikihouse_download

    # Exit if the computer is not online.
    if not Sketchup.is_online
      UI.messagebox "You need to be connected to the internet to download #{WIKIHOUSE_TITLE} models."
      return
    end

    dialog = UI::WebDialog.new("#{WIKIHOUSE_TITLE} - Download",
      true, "#{WIKIHOUSE_TITLE}-Download", 480, 640, 150, 150, true)

    dialog.add_action_callback("download") { |dialog, params|
      self.wikihouse_download_callback(dialog, params)
    }

    dialog.add_action_callback("save") { |dialog, download_id|
      self.wikihouse_save_callback(dialog, download_id)
    }

    dialog.add_action_callback("error") { |dialog, download_id|
      self.wikihouse_error_callback(dialog, download_id)
    }

    # Set the dialog's url and display it.
    dialog.set_url WIKIHOUSE_DOWNLOAD_URL
    if WIKIHOUSE_MAC
      dialog.show_modal
    else
      dialog.show
    end

  end

  # ------------------------------------------------------------------------------
  # Upload Web Dialogue
  # ------------------------------------------------------------------------------

  def self.load_wikihouse_upload

    # Exit if the computer is not online.
    if not Sketchup.is_online
      UI.messagebox "You need to be connected to the internet to upload models to #{WIKIHOUSE_TITLE}."
      return
    end

    model = Sketchup.active_model

    # Exit if a model wasn't available.
    if not model
      show_wikihouse_error "You need to open a SketchUp model to share"
      return
    end

    # Exit if it's an unsaved model.
    model_path = model.path
    if model_path == ""
      UI.messagebox "You need to save the model before it can be shared at #{WIKIHOUSE_TITLE}"
      return
    end

    # Initialise an attribute dictionary for custom metadata.
    model.start_operation('Upload WikiHouse')
    self.init_wikihouse_attributes()
    model.commit_operation

    # Auto-save the model if it has been modified.
    if model.modified?
      if not self.save_model(model)
        show_wikihouse_error "Couldn't auto-save the model to #{model_path}"
        return
      end
    end

    # Try and infer the model's name.
    model_name = model.name
    if model_name == ""
      model_name = model.title
    end

    # Instantiate an upload web dialog.
    dialog = UI::WebDialog.new("#{WIKIHOUSE_TITLE} - Upload",
      true, "#{WIKIHOUSE_TITLE}-Upload", 480, 640, 150, 150, true)

    # Load Callback
    # -------------
    # Load default values into the upload form.
    dialog.add_action_callback("load") { |dialog, params|
      if model_name != ""
        if dialog.get_element_value("design-title") == ""
          set_dom_value dialog, "design-title", model_name
        end
      end
      if model.description != ""
        if dialog.get_element_value("design-description") == ""
          set_dom_value dialog, "design-description", model.description
        end
      end
      if Sketchup.version
        set_dom_value dialog, "design-sketchup-version", Sketchup.version
      end
      set_dom_value dialog, "design-plugin-version", EXTENSION.version
    }

    # Process Callback
    # --------------
    # Process and prepare the model related data for upload.
    dialog.add_action_callback("process") { |dialog, params|

      # (?) Shouldn't the callback fetch the model filename again?
      if File.size(model_path) > 12582912
        reply = UI.messagebox "The model file is larger than 12MB. Would you like to purge unused objects, materials and styles?", MB_OKCANCEL
        if reply == IDOK
          model.layers.purge_unused
          model.styles.purge_unused
          model.materials.purge_unused
          model.definitions.purge_unused
          if not self.save_model(model)
            show_wikihouse_error "Couldn't save the purged model to #{model_path}"
            dialog.close
            return
          end
          if File.size(model_path) > 12582912
            UI.messagebox "The model file is still larger than 12MB after purging. Please break up the file into smaller components."
            dialog.close
            return
          end
        else
          dialog.close
        end
      end

      # Get the model file data.
      model_data = File.open(model_path, 'rb') do |io|
        io.read
      end

      model_data = [model_data].pack('m')
      set_dom_value dialog, "design-model", model_data

      # Capture the current view info.
      view = model.active_view
      camera = view.camera
      eye, target, up = camera.eye, camera.target, camera.up
      center = model.bounds.center

      # Get the data for the model's front image.
      front_thumbnail = get_wikihouse_thumbnail model, view, "front"
      if not front_thumbnail
        show_wikihouse_error "Couldn't generate thumbnails for the model: #{model_name}"
        dialog.close
        return
      end

      front_thumbnail = [front_thumbnail].pack('m')
      set_dom_value dialog, "design-model-preview", front_thumbnail

      # Rotate the camera and zoom all the way out.
      rotate = Geom::Transformation.rotation center, Z_AXIS, 180.degrees
      camera.set eye.transform(rotate), center, Z_AXIS
      view.zoom_extents

      # Get the data for the model's back image.
      back_thumbnail = get_wikihouse_thumbnail model, view, "back"
      if not back_thumbnail
        camera.set eye, target, up
        show_wikihouse_error "Couldn't generate thumbnails for the model: #{model_name}"
        dialog.close
        return
      end

      back_thumbnail = [back_thumbnail].pack('m')
      set_dom_value dialog, "design-model-preview-reverse", back_thumbnail

      # Set the camera view back to the original setup.
      camera.set eye, target, up

      # Get the generated sheets data.
      svg_data = self.make_wikihouse(model, false)
      if not svg_data
        return
      end
    
      set_dom_value dialog, "design-sheets-preview", svg_data

      WIKIHOUSE_UPLOADS[dialog] = 1
      dialog.execute_script "wikihouse.upload();"
    }

    # Uploaded Callback
    # -----------------
    dialog.add_action_callback "uploaded" do |dialog, params|
      if WIKIHOUSE_UPLOADS.key? dialog
        WIKIHOUSE_UPLOADS.delete dialog
      end
      if params == "success"
        UI.messagebox "Successfully uploaded #{model_name}"
      else
        UI.messagebox "Upload to #{WIKIHOUSE_TITLE} failed. Please try again."
      end
    end

    dialog.add_action_callback "download" do |dialog, params|
      self.wikihouse_download_callback dialog, params
    end

    dialog.add_action_callback "save" do |dialog, download_id|
      self.wikihouse_save_callback dialog, download_id
    end

    dialog.add_action_callback "error" do |dialog, download_id|
      self.wikihouse_error_callback dialog, download_id
    end

    # TODO(tav): There can be a situation where the dialog has been closed, but
    # the upload succeeds and the dialog gets called with "uploaded" and brought
    # to front.
    dialog.set_on_close do
      dialog.set_url "about:blank"
      if WIKIHOUSE_UPLOADS.key? dialog
        show_wikihouse_error "Upload to #{WIKIHOUSE_TITLE} has been aborted"
        WIKIHOUSE_UPLOADS.delete dialog
      end
    end

    dialog.set_url WIKIHOUSE_UPLOAD_URL
    if WIKIHOUSE_MAC
      dialog.show_modal
    else
      dialog.show
    end

  end

  # ------------------------------------------------------------------------------
  # Make Web Dialog
  # ------------------------------------------------------------------------------

  def self.load_wikihouse_make
  
    model = Sketchup.active_model
  
    # Exit if a model wasn't available.
    if not model
      show_wikihouse_error "You need to open a SketchUp model before it can be fabricated"
      return
    end
  
    # Exit if it's an unsaved model.
    model_path = model.path
    if model_path == ""
      UI.messagebox "You need to save the model before the cutting sheets can be generated"
      return
    end
  
    # Try and infer the model's filename.
    filename = model.title
    if filename == ""
      filename = "Untitled"
    end

    # Initialise an attribute dictionary for custom metadata.
    model.start_operation('Make WikiHouse')
    self.init_wikihouse_attributes()
    model.commit_operation
  
    # Get the model's parent directory and generate the new filenames to save to.
    directory = File.dirname(model_path)
    svg_filename = File.join(directory, filename + ".svg")
  
    # Make the cutting sheets for the house!
    svg_data = self.make_wikihouse(model, true)
    if not svg_data
      return
    end

    # Save the SVG data to the file.
    File.open(svg_filename, "wb") do |io|
      io.write svg_data
    end
  
    UI.messagebox "Cutting sheets successfully saved to #{directory}", MB_OK
  
    dialog = UI::WebDialog.new("Cutting Sheets Preview",
      true, "#{WIKIHOUSE_TITLE}-Preview", 800, 800, 150, 150, true)
    dialog.set_file svg_filename
    if WIKIHOUSE_MAC
      dialog.show_modal
    else
      dialog.show
    end
  
  end
  
  # ------------------------------------------------------------------------------
  # Settings Web Dialogue
  # ------------------------------------------------------------------------------

  def self.load_wikihouse_settings

    # Create WebDialog
    dialog = UI::WebDialog.new("#{WIKIHOUSE_TITLE} - Settings",
      true, "#{WIKIHOUSE_TITLE}-Settings", 480, 600, 150, 150, true)

    # Get Current WikiHouse Settings
    dialog.add_action_callback('fetch_settings') { |d, args|

      if args == 'default'
        settings = DEFAULT_SETTINGS
      elsif args == 'current'
        settings = WikiHouseExtension.settings
      end

      if args == 'default' || args == 'current'
        # Convert Dimenstions to mm
        dims = {}
        for k, v in settings do
          dims[k] = v.to_mm
        end
        script = "recieve_wikihouse_settings('#{JSON.to_json(dims)}');"
        d.execute_script(script)
      end

    }

    # Set Web Dialog's Callbacks
    dialog.add_action_callback("update_settings") { |d, args|

      close_flag = false
      if args.include? "--close"
        close_flag = true
        args = args.gsub("--close", "")
      end

      #      UI.messagebox("Passed Arguments = #{args}")
      settings = WikiHouseExtension.settings
      new_settings = JSON.from_json(args)

      for k,v in new_settings do
        # Convert mm back to inches
        settings[k] = v.mm
      end

      # Recalculate inner heights and widths
      settings["sheet_inner_height"] = settings["sheet_height"] - (2 * settings["margin"])
      settings["sheet_inner_width"] = settings["sheet_width"] - (2 * settings["margin"])

      puts "Dimensions Updated!"

      if close_flag == true
        d.close
      else
        d.execute_script("display_status('" + "Settings Updated!" + "');")
      end
    }

    # Cancel and close dialog
    dialog.add_action_callback("cancel_settings") { |d, args|
      d.close }

    # Set HTML
    html_path = File.join(WEBDIALOG_PATH, 'settings.html')
    dialog.set_file(html_path)
    if WIKIHOUSE_MAC
      dialog.show_modal
    else
      dialog.show
    end

    puts "Dialog Loaded"

  end

end