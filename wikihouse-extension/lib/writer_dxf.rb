module WikiHouseExtension   

  class DXF_Writer < Writer

def getXYZdxfCode(point,delta)
    lignes = [10+delta,20+delta,30+delta]
    code = ""
    for n in 0..2
        code += " "+lignes[n].to_s
        code +="
"
        if n == 2
            value = "0.0"
            else
            value = point[n].to_f*25.4
        end
        code += value.to_s
        code +="
"
    end
    return code
end

def getPolylineCode(points,calque,number)
    code = "POLYLINE
"
    code += getCalqueDxfCode(calque)
    code += "66
     1
70
    8
 10
 0.0
 20
 0.0
 30
0.0
"
    #code += getNumberDxfCode(number)
    points.each{|point|
        code += "  0
VERTEX
"
        code += getCalqueDxfCode(calque)
        code += getXYZdxfCode(point,0)
        code += " 70
    32
"
    }
    
    code += "  0
SEQEND
 0
"
    return code
end

def dxfrectangle(x,y,w,h,layer,number=0)
    points = []
    points << [x,y]
    points << [x+w,y]
    points << [x+w,y+h]
    points << [x,y+h]
    points << [x,y]
    return getPolylineCode(points,layer,number)
end

def getCalqueDxfCode(calque)
    code = "  8
"
    code += calque.to_s
    code +="
"
    return code
end

def getCircleDxfCode(centre,diam,calque,number)
    code = "CIRCLE
"
    #code += getNumberDxfCode(number)
    code += getCalqueDxfCode(calque)
    code += getXYZdxfCode(centre,0)
    code += " 40
"
    diametre = diam.to_f*25.4
    code += diametre.to_s
    code += "
 0
"
    return code
end

def getEnddxfFile
    code ="ENDSEC
 0
EOF"
    return code
end

def generate
    
    layout = @layout
    scale = @scale
    
    sheet_height, sheet_width, inner_height, inner_width, margin = layout.dimensions
    sheets = layout.sheets
    count = sheets.length
    
    scaled_height = scale * sheet_height
    scaled_width = scale * sheet_width
    total_height = scale * ((count * (sheet_height + (12 * margin))) + (margin * 10))
    total_width = scale * (sheet_width + (margin * 2))
    
    svgdxf = "  0
SECTION
 2
ENTITIES
 0
"
    loop_count = 0
    layer = Sketchup.active_model.active_layer.name
    for s in 0...count
        number = 0
        
        sheet = sheets[s]
        base_x = scale * margin
        base_y = scale * ((s * (sheet_height + (12 * margin))) + (margin * 9))
        
        svgdxf += dxfrectangle(base_x,base_y,scaled_width,scaled_height,layer)
        
        base_x += scale * margin
        base_y += scale * margin
        
        sheet.each do |loops, circles, outer_mapped, centroid, label|
            
            Sketchup.set_status_text WIKIHOUSE_SVG_STATUS[(loop_count/5) % 5]
            loop_count += 1
            
            for i in 0...loops.length
                circle = circles[i]
                if circle
                    center, radius = circle
                    x = (scale * center.x) + base_x
                    y = (scale * center.y) + base_y
                    radius = scale * radius
                    svgdxf += getCircleDxfCode([x,y,0],radius,layer,number)
                    else
                    loop = loops[i]
                    path = []
                    loop << loop.first
                    loop.each do |point|
                        path << [(scale * point.x) + base_x,(scale * point.y) + base_y,0]
                    end
                    svgdxf += getPolylineCode(path,layer,number)
                end
            end
            
            #if label and label != ""
            #  svgdxf << <<-LABEL.gsub(/^ {12}/, '')
            #    <text x="#{(scale * centroid.x) + base_x}" y="#{(scale * centroid.y) + base_y}" style="font-size: 5mm; stroke: rgb(255, 0, 0); fill: rgb(255, 0, 0); text-family: monospace">#{label}</text>
            #    LABEL
            #end
        end
    end
    
    svgdxf += getEnddxfFile
    end
  end


end # module
