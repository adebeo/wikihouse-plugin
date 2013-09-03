module WikiHouseExtension

  class WikiHousePanel
  
    attr_accessor :area, :centroid, :circles, :labels, :loops, :max, :min
    attr_reader :bounds_area, :error, :no_padding, :shell_area, :singleton
  
    def initialize(root, face, transform, labels, limits)
  
      # Initalise some of the object attributes.
      @error = nil
      @labels = labels
      @no_padding = false
      @singleton = false
  
      # Initialise a variable to hold temporarily generated entities.
      to_delete = []
  
      # Create a new face with the vertices transformed if the transformed areas
      # do not match.
      if (face.area - face.area(transform)).abs > 0.1
        group_entity = root.add_group
        to_delete << group_entity
        group = group_entity.entities
        tface = group.add_face(face.outer_loop.vertices.map {|v| transform * v.position })
        face.loops.each do |loop|
          if not loop.outer?
            hole = group.add_face(loop.vertices.map {|v| transform * v.position })
            hole.erase! if hole.valid?
          end
        end
        face = tface
      end
  
      # Save the total surface area of the face.
      total_area = face.area
  
      # Find the normal to the face.
      normal = face.normal
      y_axis = normal.axes[1]
  
      # See if the face is parallel to any of the base axes.
      if normal.parallel? X_AXIS
        x, y = 1, 2
      elsif normal.parallel? Y_AXIS
        x, y = 0, 2
      elsif normal.parallel? Z_AXIS
        x, y = 0, 1
      else
        x, y = nil, nil
      end
  
      # Initialise the ``loops`` variable.
      loops = []
  
      # Initialise a reference point for transforming slanted faces.
      base = face.outer_loop.vertices[0].position
  
      # Loop through the edges and convert the face into a 2D polygon -- ensuring
      # that we are traversing the edges in the right order.
      face.loops.each do |loop|
        newloop = []
        if loop.outer?
          loops.insert 0, newloop
        else
          loops << newloop
        end
        edgeuse = first = loop.edgeuses[0]
        virgin = true
        prev = nil
        while 1
          edge = edgeuse.edge
          if virgin
            start = edge.start
            stop = edge.end
            next_edge = edgeuse.next.edge
            next_start = next_edge.start
            next_stop = next_edge.end
            if (start == next_start) or (start == next_stop)
              stop, start = start, stop
            elsif not ((stop == next_start) or (stop == next_stop))
              @error = "Unexpected edge connection"
              return
            end
            virgin = nil
          else
            start = edge.start
            stop = edge.end
            if stop == prev
              stop, start = start, stop
            elsif not start == prev
              @error = "Unexpected edge connection"
              return
            end
          end
          if x
            # If the face is parallel to a base axis, use the cheap conversion
            # route.
            point = start.position.to_a
            newloop << [point[x], point[y], 0]
          else
            # Otherwise, handle the case where the face is angled at a slope by
            # realigning edges relative to the origin and rotating them according
            # to their angle to the y-axis.
            point = start.position
            edge = Geom::Vector3d.new(point.x - base.x, point.y - base.y, point.z - base.z)
            if not edge.valid?
              newloop << [base.x, base.y, 0]
            else
              if edge.samedirection? y_axis
                angle = 0
              elsif edge.parallel? y_axis
                angle = Math::PI
              else
                angle = edge.angle_between y_axis
                if not edge.cross(y_axis).samedirection? normal
                  angle = -angle
                end
              end
              rotate = Geom::Transformation.rotation ORIGIN, Z_AXIS, angle
              newedge = rotate * Geom::Vector3d.new(edge.length, 0, 0)
              newloop << [base.x + newedge.x, base.y + newedge.y, 0]
            end
          end
          edgeuse = edgeuse.next
          if edgeuse == first
            break
          end
          prev = stop
        end
      end
  
      # Initialise some more meta variables.
      areas = []
      circles = []
      cxs, cys = [], []
      intersections = []
      outer_loop = true
  
      # Go through the various loops calculating centroids and intersection points
      # of potential curves.
      loops.each do |loop|
        idx = 0
        intersect_points = []
        area = 0
        cx, cy = 0, 0
        while 1
          # Get the next three points on the loop.
          p1, p2, p3 = loop[idx...idx+3]
          if not p3
            if not p1
              break
            end
            if not p2
              # Loop around to the first edge.
              p2 = loop[0]
              p3 = loop[1]
            else
              # Loop around to the first point.
              p3 = loop[0]
            end
          end
          # Construct the edge vectors.
          edge1 = Geom::Vector3d.new(p2.x - p1.x, p2.y - p1.y, p2.z - p1.z)
          edge2 = Geom::Vector3d.new(p3.x - p2.x, p3.y - p2.y, p3.z - p2.z)
          intersect = nil
          if not edge1.parallel? edge2
            # Find the perpendicular vectors.
            cross = edge1.cross edge2
            vec1 = edge1.cross cross
            vec2 = edge2.cross cross
            # Find the midpoints.
            mid1 = Geom.linear_combination 0.5, p1, 0.5, p2
            mid2 = Geom.linear_combination 0.5, p2, 0.5, p3
            # Try finding an intersection.
            line1 = [mid1, vec1]
            line2 = [mid2, vec2]
            intersect = Geom.intersect_line_line line1, line2
            # If no intersection, try finding one in the other direction.
            if not intersect
              vec1.reverse!
              vec2.reverse!
              intersect = Geom.intersect_line_line line1, line2
            end
          end
          intersect_points << intersect
          if p3
            x1, y1 = p1.x, p1.y
            x2, y2 = p2.x, p2.y
            cross = (x1 * y2) - (x2 * y1)
            area += cross
            cx += (x1 + x2) * cross
            cy += (y1 + y2) * cross
          end
          idx += 1
        end
        intersections << intersect_points
        area = area * 0.5
        areas << area.abs
        cxs << (cx / (6 * area))
        cys << (cy / (6 * area))
        outer_loop = false
      end
  
      # Allocate variables relating to the minimal alignment.
      bounds_area = nil
      bounds_min = nil
      bounds_max = nil
      transform = nil
      outer = loops[0]
  
      # Unpack panel dimension limits.
      panel_height, panel_width, panel_max_height, panel_max_width, padding = limits
  
      # Try rotating at half degree intervals and find the transformation which
      # occupies the most minimal bounding rectangle.
      (0...180.0).step(0.5) do |angle|
        t = Geom::Transformation.rotation ORIGIN, Z_AXIS, angle.degrees
        bounds = Geom::BoundingBox.new
        outer.each do |point|
          point = t * point
          bounds.add point
        end
        min, max = bounds.min, bounds.max
        height = max.y - min.y
        width = max.x - min.x
        if (height - panel_height) > 0.1
          next
        end
        if (width - panel_width) > 0.1
          next
        end
        area = width * height
        if (not bounds_area) or ((bounds_area - area) > 0.1)
          bounds_area = area
          bounds_min, bounds_max = min, max
          transform = t
        end
      end
      
      # If we couldn't find a fitting angle, try again at 0.1 degree intervals.
      if not transform
        (0...180.0).step(0.1) do |angle|
          t = Geom::Transformation.rotation ORIGIN, Z_AXIS, angle.degrees
          bounds = Geom::BoundingBox.new
          outer.each do |point|
            point = t * point
            bounds.add point
          end
          min, max = bounds.min, bounds.max
          height = max.y - min.y
          width = max.x - min.x
          if (width - panel_max_width) > 0.1
            next
          end
          if (height - panel_max_height) > 0.1
            next
          end
          area = width * height
          if (not bounds_area) or ((bounds_area - area) > 0.1)
            bounds_area = area
            bounds_min, bounds_max = min, max
            transform = t
          end
        end
      end
  
      # If we still couldn't find a fitting, abort.
      if not transform
        @error = "Couldn't fit panel within cutting sheet"
        puts @error
        return
      end
  
      # Set the panel to a singleton panel (i.e. without any padding) if it is
      # larger than the height and width, otherwise set the no_padding flag.
      width = bounds_max.x - bounds_min.x
      height = bounds_max.y - bounds_min.y
      if (width + padding) > panel_width
        @no_padding = 'w'
      end
      if (height + padding) > panel_height
        if @no_padding
          @singleton = true
          @no_padding = nil
        else
          @no_padding = 'h'
        end
      end
  
      # Transform all points on every loop.
      loops.map! do |loop|
        loop.map! do |point|
          transform * point
        end
      end
  
      # Find the centroid.
      @shell_area = surface_area = areas.shift
      topx = surface_area * cxs.shift
      topy = surface_area * cys.shift
      for i in 0...areas.length
        area = areas[i]
        topx -= area * cxs[i]
        topy -= area * cys[i]
        surface_area -= area
      end
      cx = topx / surface_area
      cy = topy / surface_area
      centroid = transform * [cx, cy, 0]
  
      # Sanity check the surface area calculation.
      if (total_area - surface_area).abs > 0.1
        @error = "Surface area calculation differs"
        return
      end
  
      # TODO(tav): We could also detect arcs once we figure out how to create
      # polylined shapes with arcs in the DXF output. This may not be ideal as
      # polyarcs may also cause issues with certain CNC routers.
  
      # Detect all circular loops.
      for i in 0...loops.length
        points = intersections[i]
        length = points.length
        last = length - 1
        circle = true
        for j in 0...length
          c1 = points[j]
          c2 = points[j+1]
          if j == last
            c2 = points[0]
          end
          if not (c1 and c2)
            circle = false
            break
          end
          if ((c2.x - c1.x).abs > 0.1) or ((c2.y - c1.y).abs > 0.1)
            circle = false
            break
          end
        end
        if circle and length >= 24
          center = transform * points[0]
          p1 = loops[i][0]
          x = center.x - p1.x
          y = center.y - p1.y
          radius = Math.sqrt((x * x) + (y * y))
          circles[i] = [center, radius]
        end
      end
  
      # Save the generated data.
      @area = total_area
      @bounds_area = bounds_area
      @centroid = centroid
      @circles = circles
      @loops = loops
      @max = bounds_max
      @min = bounds_min
  
      # Delete any temporarily generated groups.
      if to_delete.length > 0
        root.erase_entities to_delete
      end
  
    end
  
  end # class

end # module
