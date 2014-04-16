module WikiHouseExtension

  class WikiHouseEntities
    
    attr_accessor :orphans, :panels
  
    def initialize(entities, root, dimensions)
  
      @count_s1 = 0
      @count_s2 = 0
      @count_s3 = 0
      @count_s4 = 0
  
      # Initialise the default attribute values.
      @faces = Hash.new
      @groups = groups = Hash.new
      @orphans = orphans = Hash.new
      @root = root
      @to_delete = []
      @todo = todo = []
  
      # Set a loop counter variable and the default identity transformation.
      loop = 0
      transform = Geom::Transformation.new
  
      # Aggregate all the entities into the ``todo`` array.
      entities.each { |entity| todo << [entity, transform] }
  
      # Visit all component and group entities defined within the model and count
      # up all orphaned face entities.
      while todo.length != 0
        Sketchup.set_status_text WIKIHOUSE_DETECTION_STATUS[(loop/10) % 5] # Loop through status msg 
        loop += 1
        entity, transform = todo.pop
        case entity
        when Sketchup::Group, Sketchup::ComponentInstance
          visit entity, transform
        when Sketchup::Face
          if orphans[WIKIHOUSE_DUMMY_GROUP]
            orphans[WIKIHOUSE_DUMMY_GROUP] += 1
          else
            orphans[WIKIHOUSE_DUMMY_GROUP] = 1
          end
        end
      end
  
      # If there were no orphans, unset the ``@orphans`` attribute.
      if not orphans.length > 0
        @orphans = nil
      end
  
      # Reset the loop counter.
      loop = 0
  
      # Construct the panel limit dimensions.
      height, width, padding = [dimensions[2], dimensions[3], dimensions[5]]
      padding = 2 * padding
      limits = [height - padding, width - padding, height, width, padding]
  
      # Loop through each group and aggregate parsed data for the faces.
      @panels = items = []
      @faces.each_pair do |group, faces|
        meta = groups[group]
        sample = faces[0]
        if meta.length == 1
          f_data = { meta[0][0] => [meta[0][1]] }
        else
          f_data = Hash.new
          meta = meta.map { |t, l| [t, l, sample.area(t)] }.sort_by { |t| t[2] }
          while meta.length != 0
            t1, l1, a1 = meta.pop
            idx = -1
            f_data[t1] = [l1]
            while 1
              f2_data = meta[idx]
              if not f2_data
                break
              end
              t2, l2, a2 = f2_data
              if (a2 - a1).abs > 0.1
                break
              end
              f_data[t1] << l2
              meta.delete_at idx
            end
          end
        end
        f_data.each_pair do |transform, labels|
          panels = faces.map do |face|
            Sketchup.set_status_text WIKIHOUSE_PANEL_STATUS[(loop/3) % 5]
            loop += 1
            WikiHousePanel.new root, face, transform, labels, limits
          end
          items.concat panels
        end
      end
  
      total = 0
      items.each { |item| total += item.labels.length }
  
      if @orphans
        puts "Orphans: #{@orphans.length} Groups"
      end
  
      puts "Items: #{total}"
      puts "S1: #{@count_s1}"
      puts "S2: #{@count_s2}"
      puts "S3: #{@count_s3}"
      puts "S4: #{@count_s4}"
      
    end
  
    def visit(group, transform)
  
      # Setup some local variables.
      exists = false
      faces = []
      groups = @groups
  
      # Setup the min/max heights for the depth edge/faces.
      min_height = WikiHouseExtension.settings["sheet_depth"] - 1.mm
      max_height = WikiHouseExtension.settings["sheet_depth"] + 1.mm
      # min_height = 17.mm
      # max_height = 19.mm
  
      # Apply the transformation if one has been set for this group.
      if group.transformation
        transform = transform * group.transformation
      end
  
      # Get the label.
      label = group.name
      if label == ""
        label = nil
      end
  
      # Get the entities set.
      case group
      when Sketchup::Group
        entities = group.entities
      else # is component
        group = group.definition
        entities = group.entities
        # Check if we've seen this component before, and if so, reuse previous
        # data.
        if groups[group]
          groups[group] << [transform, label]
          entities.each do |entity|
            case entity
            when Sketchup::Group, Sketchup::ComponentInstance
              @todo << [entity, transform]
            end
          end
          return
        end
      end
  
      # Add the new group/component definition.
      groups[group] = [[transform, label]]
  
      # Loop through the entities.
      entities.each do |entity|
        case entity
        when Sketchup::Face
          edges = entity.edges
          ignore = 0
          # Ignore all faces which match the specification for the depth side.
          if edges.length == 4
            for i in 0...4
              edge = edges[i]
              length = edge.length
              if length < max_height and length > min_height
                ignore += 1
                if ignore == 2
                  break
                end
              end
            end
          end
          if WIKIHOUSE_HIDE and ignore == 2
            entity.hidden = false
          end
          if ignore != 2 # TODO(tav): and entity.visible?
            faces << entity
          end
        when Sketchup::Group, Sketchup::ComponentInstance
          # Append the entity to the todo attribute instead of recursively calling
          # ``visit`` so as to avoid blowing the stack.
          @todo << [entity, transform]
        end
      end
  
      faces, orphans = visit_faces faces, transform
  
      if orphans and orphans.length > 0
        @orphans[group] = orphans.length
      end
  
      if faces and faces.length > 0
        @faces[group] = faces
      end
  
    end
  
    def visit_faces(faces, transform)
  
      # Handle the case where no faces have been found or just a single orphaned
      # face exists.
      if faces.length <= 1
        if faces.length == 0
          return [], nil
        else
          return [], faces
        end
      end
  
      # Define some local variables.
      found = []
      orphans = []
  
      # Sort the faces by their respective surface areas in order to minimise
      # lookups.
      faces = faces.sort_by { |face| face.area transform }
  
      # Iterate through the faces and see if we can find matching pairs.
      while faces.length != 0
        face1 = faces.pop
        area1 = face1.area transform
        # Ignore small faces.
        if area1 < 5  # (Chris) This may be why the small C shaped parts in Joins are being ignored. 
          next
        end
        idx = -1
        match = false
        # Check against all remaining faces.
        while 1
          face2 = faces[idx]
          if not face2
            break
          end
          if face1 == face2
            faces.delete_at idx
            next
          end
          # Check that the area of both faces are close enough -- accounting for
          # any discrepancies caused by floating point rounding errors.
          area2 = face2.area transform
          diff = (area2 - area1).abs
          if diff < 0.5 # TODO(tav): Ideally, this tolerance will be 0.1 or less.
            @count_s1 += 1
            # Ensure that the faces don't intersect, i.e. are parallel to each
            # other.
            intersect = Geom.intersect_plane_plane face1.plane, face2.plane
            if intersect
              # Calculate the angle between the two planes and accomodate for
              # rounding errors.
              angle = face1.normal.angle_between face2.normal
              if angle < 0.01
                intersect = nil
              elsif (Math::PI - angle).abs < 0.01
                intersect = nil
              end
            end
            if not intersect
              @count_s2 += 1
              vertices1 = face1.vertices
              vertices2 = face2.vertices
              vertices_length = vertices1.length
              # Check if both faces have matching number of outer vertices and
              # that they each share a common edge.
              vertices1 = face1.outer_loop.vertices
              vertices2 = face2.outer_loop.vertices
              for i in 0...vertices1.length
                vertex1 = vertices1[i]
                connected = false
                for j in 0...vertices2.length
                  vertex2 = vertices2[j]
                  if vertex1.common_edge vertex2
                    connected = true
                    vertices2.delete_at j
                    break
                  end
                end
                if not connected
                  break
                end
              end
              if connected
                @count_s3 += 1
                # Go through the various loops of edges and find ones that have
                # shared edges to the other face.
                loops1 = []
                loops2 = []
                loops2_lengths = []
                face2.loops.each do |loop|
                  if not loop.outer?
                    loops2 << loop
                    loops2_lengths << loop.vertices.length
                  end
                end
                face1_loops = face1.loops
                face1_loops.each do |loop1|
                  if not loop1.outer?
                    loop1_vertices = loop1.vertices
                    loop1_length = loop1_vertices.length
                    for l in 0...loops2.length
                      if loops2_lengths[l] == loop1_length
                        loop2_vertices = loops2[l].vertices
                        for i in 0...loop1_length
                          v1 = loop1_vertices[i]
                          connected = false
                          for j in 0...loop2_vertices.length
                            v2 = loop2_vertices[j]
                            if v1.common_edge v2
                              connected = true
                              loop2_vertices.delete_at j
                              break
                            end
                          end
                          if not connected
                            break
                          end
                        end
                        if connected
                          loops1 << loops2[l].vertices
                          loops2.delete_at l
                          loops2_lengths.delete_at l
                          break
                        end
                      end
                    end
                  end
                end
                # If the number of loops with shared edges don't match up with the
                # original state, create a new face.
                if loops1.length != (face1.loops.length - 1)
                  group = @root.add_group
                  group_ents = group.entities
                  face = group_ents.add_face vertices1
                  loops1.each do |v|
                    hole = group_ents.add_face v
                    hole.erase! if hole.valid?
                  end
                  @to_delete << group
                else
                  face = face1
                end
                # We have matching and connected faces!
                match = true
                found << face
                faces.delete_at idx
                if WIKIHOUSE_HIDE
                  face1.hidden = true
                  face2.hidden = true
                end
                break
              end
            end
          end
          idx -= 1
        end
        if match
          next
        end
        orphans << face1
      end
  
      # Return all the found and orphaned faces.
      return found, orphans
  
    end
  
    def purge
  
      # Delete any custom generated entity groups.
      if @to_delete and @to_delete.length != 0
        @root.erase_entities @to_delete
      end
  
      # Nullify all container attributes.
      @faces = nil
      @groups = nil
      @orphans = nil
      @root = nil
      @to_delete = nil
      @todo = nil
  
    end
  
  end # class

end # module