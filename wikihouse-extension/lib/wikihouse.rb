module WikiHouseExtension 

  def self.make_wikihouse(model, interactive)
  
    # Isolate the entities to export.
    entities = root = model.active_entities
    selection = model.selection
    if selection.empty?
      if interactive
        reply = UI.messagebox "No objects selected. Export the entire model?", MB_OKCANCEL
        if reply != IDOK
          return
        end
      end
    else
      entities = selection
    end
  
    settings = WikiHouseExtension.settings
    dimensions = [
      settings['sheet_height'],
      settings['sheet_width'],
      settings['sheet_inner_height'],
      settings['sheet_inner_width'],
      settings['margin'],
      settings['padding'],
      settings['font_height']
    ]

    model.start_operation('Make WikiHouse', true)
    begin

      # Load and parse the entities.
      if WIKIHOUSE_SHORT_CIRCUIT && @@wikloader # Converted from global. Could be instance?
        loader = @@wikloader
      else
        loader = WikiHouseEntities.new entities, root, dimensions
        if WIKIHOUSE_SHORT_CIRCUIT
          @@wikloader = loader
        end
      end
    
      if interactive and loader.orphans
        msg = "The cutting sheets may be incomplete. The following number of faces could not be matched appropriately:\n\n"
        loader.orphans.each_pair do |group, count|
          msg += "    #{count} in #{group.name.length > 0 and group.name or 'Group#???'}\n"
        end
        UI.messagebox msg
      end
    
      # Filter out any panels which raised an error.
      panels = loader.panels.select { |panel| !panel.error }
    
      # Run the detected panels through the layout engine.
      layout = WikiHouseLayoutEngine.new panels, root, dimensions
    
      # Generate the SVG file.
      svg = SVG_Writer.new(layout, 8)
      svg_data = svg.generate
    
      # Generate the DXF file.
      #dxf = DXF_Writer.new(layout)
      #dxf_data = dxf.generate
    
      # Cleanup.
      Sketchup.set_status_text ""
      loader.purge

    ensure
      # This aborts all the temp operations performed during export. Leaving
      # the Undo stack clean and model unchanged.
      model.abort_operation
    end
  
    # Return the generated data.
    [svg_data, dxf_data]
  
  end


  def self.init_wikihouse_attributes
    model = Sketchup.active_model
    dictionary = model.attribute_dictionary(WIKIHOUSE_TITLE, true)
    if dictionary.size == 0
      dictionary['spec'] = EXTENSION.version
    end
  end

end # module
