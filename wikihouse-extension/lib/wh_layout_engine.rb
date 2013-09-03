module WikiHouseExtension

  class WikiHouseLayoutEngine
    
    attr_accessor :sheets
    attr_reader :dimensions
  
    def initialize(panels, root, dimensions)
  
      @dimensions = dimensions
      @sheets = sheets = []
  
      # Set local variables to save repeated lookups.
      sheet_height, sheet_width, inner_height, inner_width,
      sheet_margin, panel_padding, font_height = dimensions
  
      # Filter out the singletons from the other panels.
      singletons = panels.select { |panel| panel.singleton }
      panels = panels.select { |panel| !panel.singleton }
  
      # Loop through the panels.
      panels.map! do |panel|
  
        # Get padding related info.
        no_padding = panel.no_padding
  
        # Get the bounding box.
        min = panel.min
        max = panel.max
        min_x, min_y = min.x, min.y
        max_x, max_y = max.x, max.y
  
        # Set a flag to indicate clipped panels.
        clipped = false
  
        # Determine if the potential savings exceeds the hard-coded threshold. If
        # so, see if we can generate an outline with rectangular areas clipped
        # from each corner.
        if (panel.bounds_area - panel.shell_area) > 50
          # puts (panel.bounds_area - panel.shell_area)
        end
  
        # Otherwise, treat the bounding box as the outline.
        if not clipped
  
          # Define the inner outline.
          inner = [[min_x, min_y, 0], [max_x, min_y, 0], [max_x, max_y, 0], [min_x, max_y, 0]]
  
          # Add padding around each side.
          if not no_padding
            min_x -= panel_padding
            min_y -= panel_padding
            max_x += panel_padding
            max_y += panel_padding
          elsif no_padding == "w"
            min_y -= panel_padding
            max_y += panel_padding
          elsif no_padding == "h"
            min_x -= panel_padding
            max_x += panel_padding
          end
  
          # Calculate the surface area that will be occupied by this panel.
          width = max_x - min_x
          height = max_y - min_y
          area = width * height
  
          # Define the padded outer outline.
          # outline = [[min_x, max_y, 0], [max_x, max_y, 0], [max_x, min_y, 0], [min_x, min_y, 0]]
          outer = [[min_x, min_y, 0], [max_x, min_y, 0], [max_x, max_y, 0], [min_x, max_y, 0]]
          outlines = [[nil, inner, outer]]
  
          # See if the panel can be rotated, if so add the transformation.
          if not no_padding
            if (inner_width > height) and (inner_height > width)
              # inner = [inner[3], inner[0], inner[1], inner[2]]
              # outer = [outer[3], outer[0], outer[1], outer[2]]
              outlines << [90.degrees, inner, outer]
              outlines << [270.degrees, inner, outer]
            end
            outlines << [180.degrees, inner, outer]
          end
  
        end
  
        # Save the generated data.
        [panel, outlines, area, panel.labels.dup]
  
      end
  
      # Sort the panels by surface area.
      panels = panels.sort_by { |data| data[2] }.reverse
  
      # Generate new groups to hold sheet faces.
      inner_group = root.add_group
      inner_faces = inner_group.entities
      outer_group = root.add_group
      outer_faces = outer_group.entities
      temp_group = root.add_group
      temp_faces = temp_group.entities
      total_area = inner_width * inner_height
  
      # Initialise the loop counter.
      loop_count = 0
  
      # Make local certain global constants.
      outside = Sketchup::Face::PointOutside
  
      # panels = panels[-10...-1]
      # panels = panels[-5...-1]
      c = 0
  
      # Do the optimising layout.
      while 1
  
        # Create a fresh sheet.
        sheet = []
        available_area = total_area
        idx = 0
        placed_i = []
        placed_o = []
  
        while available_area > 0
  
          Sketchup.set_status_text WIKIHOUSE_LAYOUT_STATUS[(loop_count/20) % 5]
          loop_count += 1
  
          panel_data = panels[idx]
          if not panel_data
            break
          end
  
          panel, outlines, panel_area, labels = panel_data
          if panel_area > available_area
            idx += 1
            next
          end
  
          match = true
          t = nil
          used = nil
  
          # If this is the first item, do the cheap placement check.
          if sheet.length == 0
            transform, inner, outer = outlines[0]
            point = outer[0]
            translate = Geom::Transformation.translation [-point[0], -point[1], 0]
            inner.each do |point|
              point = translate * point
              if (point.x > inner_width) or (-point.y > inner_height)
                p (point.x - inner_width)
                p (point.y - inner_height)
                match = false
                break
              end
            end
            if not match
              puts "Error: couldn't place panel onto an empty sheet"
              panels.delete_at idx
              next
            end
            t = translate
            used = [inner, outer]
          else
            # Otherwise, loop around the already placed panel regions and see if
            # the outline can be placed next to it.
            match = false
            placed_o.each do |face|
              # Loop through the vertices of the available region.
              face.outer_loop.vertices.each do |vertex|
                origin = vertex.position
                # Loop through each outline.
                outlines.each do |angle, inner, outer|
                  # Loop through every vertex of the outline, starting from the
                  # top left.
                  p_idx = -1
                  all_match = true
                  while 1
                    p0 = outer[p_idx]
                    if not p0
                      break
                    end
                    transform = Geom::Transformation.translation([origin.x - p0[0], origin.y - p0[1], 0])
                    if angle
                      transform = transform * Geom::Transformation.rotation(origin, Z_AXIS, angle)
                    end
                    # Check every point to see if it's within the available region.
                    all_match = true
                    inner.each do |point|
                      point = transform * point
                      px, py = point.x, point.y
                      if (px < 0) or (py < 0) or (px > inner_width) or (py > inner_height)
                        all_match = false
                        break
                      end
                      placed_o.each do |placement|
                        if placement.classify_point(point) != outside
                          all_match = false
                          break
                        end
                      end
                      if not all_match
                        break
                      end
                    end
                    # If the vertices don't overlap, check that the edges don't
                    # intersect.
                    if all_match
                      # TODO(tav): Optimise with a sweep line algorithm variant:
                      # http://en.wikipedia.org/wiki/Sweep_line_algorithm
                      outer_mapped = outer.map { |point| transform * point }
                      for i in 0...outer.length
                        p1 = outer_mapped[i]
                        p2 = outer_mapped[i+1]
                        if not p2
                          p2 = outer_mapped[0]
                        end
                        p1x, p1y = p1.x, p1.y
                        p2x, p2y = p2.x, p2.y
                        s1 = p2x - p1x
                        s2 = p2y - p1y
                        edge = [p1, [s1, s2, 0]]
                        edge_length = Math.sqrt((s1 * s1) + (s2 * s2))
                        placed_i.each do |placement|
                          placement.edges.each do |other_edge|
                            intersection = Geom.intersect_line_line edge, other_edge.line
                            if intersection
                              p3x, p3y = intersection.x, intersection.y
                              s1 = p3x - p1x
                              s2 = p3y - p1y
                              length = Math.sqrt((s1 * s1) + (s2 * s2))
                              if length > edge_length
                                next
                              end
                              s1 = p3x - p2x
                              s2 = p3y - p2y
                              length = Math.sqrt((s1 * s1) + (s2 * s2))
                              if length > edge_length
                                next
                              end
                              other_edge_length = other_edge.length
                              p4, p5 = other_edge.start.position, other_edge.end.position
                              s1 = p3x - p4.x
                              s2 = p3y - p4.y
                              length = Math.sqrt((s1 * s1) + (s2 * s2))
                              if length > other_edge_length
                                next
                              end
                              s1 = p3x - p5.x
                              s2 = p3y - p5.y
                              length = Math.sqrt((s1 * s1) + (s2 * s2))
                              if length > other_edge_length
                                next
                              end
                              all_match = false
                              break
                            end
                          end
                          if not all_match
                            break
                          end
                        end
                        if not all_match
                          break
                        end
                      end
                    end
                    if all_match
                      match = true
                      t = transform
                      used = [inner, outer]
                    end
                    p_idx -= 1
                    if match
                      break
                    end
                  end
                  if match
                    break
                  end
                end
                if match
                  break
                end
              end
              if match
                break
              end
            end
          end
  
          if match
  
            available_area -= panel_area
            inner_faces.add_face(used[0].map { |p| t * p })
            outer_faces.add_face(used[1].map { |p| t * p })
            placed_i = inner_faces.grep(Sketchup::Face)
            placed_o = outer_faces.grep(Sketchup::Face)
  
            # Generate the new loop vertices.
            loops = panel.loops.map do |loop|
              loop.map do |point|
                t * point
              end
            end
  
            # Generate the new circle data.
            circles = panel.circles.map do |circle|
              if circle
                center = t * circle[0]
                [center, circle[1]]
              else
                nil
              end
            end
  
            # Generate the new centroid.
            centroid = t * panel.centroid
  
            # Get the label.
            label = labels.pop
  
            # If this was the last label, remove the panel.
            if labels.length == 0
              panels.delete_at idx
            end
  
            outer_mapped = outer.map { |p| t * p }
  
            # Append the generated data to the current sheet.
            sheet << [loops, circles, outer_mapped, centroid, label]
            c += 1
  
          else
  
            # We do not have a match, try the next panel.
            idx += 1
  
          end
  
        end
  
        # If no panels could be fitted, break so as to avoid an infinite loop.
        if sheet.length == 0
          break
        end
  
        # Add the sheet to the collection.
        sheets << sheet
  
        # If there are no more panels remaining, exit the loop.
        if panels.length == 0
          break
        end
  
        # Wipe the generated entities.
        inner_faces.clear!
        outer_faces.clear!
  
      end
  
      # Delete the generated sheet group.
      root.erase_entities [inner_group, outer_group]
  
    end
  
  end # class

end # module
