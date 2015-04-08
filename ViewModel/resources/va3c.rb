require 'openstudio'

if /^1\.8/.match(RUBY_VERSION)
  class Struct
    def to_h
      h = {}
      self.class.members.each{|m| h[m.to_sym] = self[m]} 
      return h
    end
  end
end

# Va3c class converts an OpenStudio model to vA3C JSON format for rendering in Three.js
# using export at http://va3c.github.io/projects/#./osm-data-viewer/latest/index.html# as a guide
# many thanks to Theo Armour and the vA3C team for figuring out many of the details here
class VA3C

  Scene = Struct.new(:geometries, :materials, :object)
  
  Geometry = Struct.new(:uuid, :type, :data)
  GeometryData = Struct.new(:vertices, :normals, :uvs, :faces, :scale, :visible, :castShadow, :receiveShadow, :doubleSided)

  Material = Struct.new(:uuid, :type, :color, :ambient, :emissive, :specular, :shininess, :side, :opacity, :transparent, :wireframe)
  
  SceneObject = Struct.new(:uuid, :type, :matrix, :children)
  SceneChild = Struct.new(:uuid, :name, :type, :geometry, :material, :matrix, :userData)
  UserData = Struct.new(:handle, :name, :surfaceType, :constructionName, :spaceName, :thermalZoneName, :outsideBoundaryCondition, :outsideBoundaryConditionObjectName, :sunExposure, :windExposure, :vertices)
  Vertex = Struct.new(:x, :y, :z)
 
  AmbientLight = Struct.new(:uuid, :type, :color, :matrix)
   
  def self.convert_model(model)
    scene = build_scene(model)

    # build up the json hash
    result = Hash.new
    result['metadata'] = { 'version' => 4.3, 'type' => 'Object', 'generator' => 'OpenStudio' }
    result['geometries'] = scene.geometries
    result['materials'] = scene.materials
    result['object'] = scene.object
    
    return result
  end
  
  # format a uuid
  def self.format_uuid(uuid)
    return uuid.to_s.gsub('{','').gsub('}','')
  end
  
  # create a material
  def self.make_material(color, opacity)

    transparent = false
    if opacity < 1
      transparent = true
    end

    material = {:uuid => "#{format_uuid(OpenStudio::createUUID)}",
                :type => 'MeshPhongMaterial',
                :color => "#{color}".hex,
                :ambient => "#{color}".hex,
                :emissive => '0x000000'.hex,
                :specular => '0x808080'.hex,
                :shininess => 50,
                :opacity => opacity,
                :transparent => transparent,
                :wireframe => false,
                :side => 2}
    return material
  end

  # create the standard materials
  def self.build_materials
    materials = []
    
    materials << make_material('0x808080', 1) # floor
    materials << make_material('0xccb266', 1) # wall
    materials << make_material('0x994c4c', 1) # roof
    materials << make_material('0x66b2cc', 0.6) # window
    materials << make_material('0x551A8B', 1) # all else
    
    return materials
  end

  # get the index of a vertex out of a list
  def self.get_vertex_index(vertex, vertices, tol = 0.001)
    vertices.each_index do |i|
      if OpenStudio::getDistance(vertex, vertices[i]) < tol
        return i
      end
    end
    vertices << vertex
    return (vertices.length - 1)
  end

  # flatten array of vertices into a single array
  def self.flatten_vertices(vertices)
    result = []
    vertices.each do |vertex|
      #result << vertex.x
      #result << vertex.y
      #result << vertex.z
      
      result << vertex.x
      result << vertex.z
      result << -vertex.y
    end
    return result
  end

  # turn a surface into geometries, the first one is the surface, remaining are sub surfaces
  def self.make_geometries(surface)
    geometries = []
    user_datas = []

    # get the transformation to site coordinates
    site_transformation = OpenStudio::Transformation.new
    planar_surface_group = surface.planarSurfaceGroup
    if not planar_surface_group.empty?
      site_transformation = planar_surface_group.get.siteTransformation
    end

    # get the vertices
    surface_vertices = surface.vertices
    t = OpenStudio::Transformation::alignFace(surface_vertices)
    r = t.rotationMatrix
    tInv = t.inverse
    surface_vertices = OpenStudio::reverse(tInv*surface_vertices)

    # get vertices of all sub surfaces
    sub_surface_vertices = OpenStudio::Point3dVectorVector.new
    sub_surfaces = surface.subSurfaces
    sub_surfaces.each do |sub_surface|
      sub_surface_vertices << OpenStudio::reverse(tInv*sub_surface.vertices)
    end

    # triangulate surface
    triangles = OpenStudio::computeTriangulation(surface_vertices, sub_surface_vertices)
    if triangles.empty?
      puts "Failed to triangulate surface #{surface.name} with #{sub_surfaces.size} sub surfaces"
      return geometries
    end

    all_vertices = []
    face_indices = []
    triangles.each do |vertices|
      vertices = site_transformation*t*vertices
      #normal = site_transformation.rotationMatrix*r*z

      # https://github.com/mrdoob/three.js/wiki/JSON-Model-format-3
      # 0 indicates triangle
      # 16 indicates triangle with normals
      face_indices << 0
      vertices.each do |vertex|
        face_indices << get_vertex_index(vertex, all_vertices)  
      end

      # convert to 1 based indices
      #face_indices.each_index {|i| face_indices[i] = face_indices[i] + 1}
    end

    data = GeometryData.new
    data.vertices = flatten_vertices(all_vertices)
    data.normals = [] 
    data.uvs = []
    data.faces = face_indices
    data.scale = 1
    data.visible = true
    data.castShadow = true
    data.receiveShadow = false
    data.doubleSided = true
    
    geometry = Geometry.new
    geometry.uuid = format_uuid(surface.handle)
    geometry.type = 'Geometry'
    geometry.data = data.to_h
    geometries << geometry.to_h
    
    surface_user_data = UserData.new
    surface_user_data.handle = format_uuid(surface.handle)
    surface_user_data.name = surface.name.to_s
    surface_user_data.surfaceType = surface.surfaceType
    surface_user_data.constructionName = nil
    if surface.construction.is_initialized
      surface_user_data.constructionName = surface.construction.get.name.to_s
    end
    surface_user_data.spaceName = nil
    surface_user_data.thermalZoneName = nil
    if surface.space.is_initialized
      space = surface.space.get
      surface_user_data.spaceName = space.name.to_s
      if space.thermalZone.is_initialized
        surface_user_data.thermalZoneName = space.thermalZone.get.name.to_s
      end
    end
    surface_user_data.outsideBoundaryCondition = surface.outsideBoundaryCondition
    surface_user_data.outsideBoundaryConditionObjectName = nil
    if surface.adjacentSurface.is_initialized
      surface_user_data.outsideBoundaryConditionObjectName = surface.adjacentSurface.get.name.to_s
    end
    surface_user_data.sunExposure = surface.sunExposure
    surface_user_data.windExposure = surface.windExposure
    vertices = []
    surface.vertices.each do |v| 
      vertex = Vertex.new
      vertex.x = v.x
      vertex.y = v.y
      vertex.z = v.z
      vertices << vertex.to_h
    end
    surface_user_data.vertices = vertices
    user_datas << surface_user_data.to_h
    
    # now add geometry for each sub surface
    sub_surfaces.each do |sub_surface|
   
      # triangulate sub surface
      sub_surface_vertices = OpenStudio::reverse(tInv*sub_surface.vertices)
      triangles = OpenStudio::computeTriangulation(sub_surface_vertices, OpenStudio::Point3dVectorVector.new)
      
      all_vertices = []
      face_indices = []
      triangles.each do |vertices|
        vertices = site_transformation*t*vertices
        #normal = site_transformation.rotationMatrix*r*z
        
        # https://github.com/mrdoob/three.js/wiki/JSON-Model-format-3
        # 0 indicates triangle
        # 16 indicates triangle with normals
        face_indices << 0
        vertices.each do |vertex|
          face_indices << get_vertex_index(vertex, all_vertices)  
        end    

        # convert to 1 based indices
        #face_indices.each_index {|i| face_indices[i] = face_indices[i] + 1}
      end
      
      data = GeometryData.new
      data.vertices = flatten_vertices(all_vertices)
      data.normals = [] 
      data.uvs = []
      data.faces = face_indices
      data.scale = 1
      data.visible = true
      data.castShadow = true
      data.receiveShadow = false
      data.doubleSided = true
      
      geometry = Geometry.new
      geometry.uuid = format_uuid(sub_surface.handle)
      geometry.type = 'Geometry'
      geometry.data = data.to_h
      geometries << geometry.to_h
      
      sub_surface_user_data = UserData.new
      sub_surface_user_data.handle = format_uuid(sub_surface.handle)
      sub_surface_user_data.name = sub_surface.name.to_s
      sub_surface_user_data.surfaceType = sub_surface.subSurfaceType
      sub_surface_user_data.constructionName = nil
      if sub_surface.construction.is_initialized
        sub_surface_user_data.constructionName = sub_surface.construction.get.name.to_s
      end     
      sub_surface_user_data.spaceName = surface_user_data.spaceName
      sub_surface_user_data.thermalZoneName = surface_user_data.thermalZoneName
      sub_surface_user_data.outsideBoundaryCondition = surface_user_data.outsideBoundaryCondition
      sub_surface_user_data.outsideBoundaryConditionObjectName = nil
      if sub_surface.adjacentSubSurface.is_initialized
        sub_surface_user_data.outsideBoundaryConditionObjectName = sub_surface.adjacentSubSurface.get.name.to_s
      end
      sub_surface_user_data.sunExposure = surface_user_data.sunExposure
      sub_surface_user_data.windExposure = surface_user_data.windExposure
      vertices = []
      surface.vertices.each do |v| 
        vertex = Vertex.new
        vertex.x = v.x
        vertex.y = v.y
        vertex.z = v.z
        vertices << vertex.to_h
      end
      sub_surface_user_data.vertices = vertices
      user_datas << sub_surface_user_data.to_h     
    end

    return [geometries, user_datas]
  end
  
  # turn a shading surface into geometries
  def self.make_shade_geometries(surface)
    geometries = []
    user_datas = []

    # get the transformation to site coordinates
    site_transformation = OpenStudio::Transformation.new
    planar_surface_group = surface.planarSurfaceGroup
    if not planar_surface_group.empty?
      site_transformation = planar_surface_group.get.siteTransformation
    end

    # get the vertices
    surface_vertices = surface.vertices
    t = OpenStudio::Transformation::alignFace(surface_vertices)
    r = t.rotationMatrix
    tInv = t.inverse
    surface_vertices = OpenStudio::reverse(tInv*surface_vertices)

    # triangulate surface
    triangles = OpenStudio::computeTriangulation(surface_vertices, OpenStudio::Point3dVectorVector.new)
    if triangles.empty?
      puts "Failed to triangulate shading surface #{surface.name}"
      return geometries
    end

    all_vertices = []
    face_indices = []
    triangles.each do |vertices|
      vertices = site_transformation*t*vertices
      #normal = site_transformation.rotationMatrix*r*z

      # https://github.com/mrdoob/three.js/wiki/JSON-Model-format-3
      # 0 indicates triangle
      # 16 indicates triangle with normals
      face_indices << 0
      vertices.each do |vertex|
        face_indices << get_vertex_index(vertex, all_vertices)  
      end

      # convert to 1 based indices
      #face_indices.each_index {|i| face_indices[i] = face_indices[i] + 1}
    end

    data = GeometryData.new
    data.vertices = flatten_vertices(all_vertices)
    data.normals = [] 
    data.uvs = []
    data.faces = face_indices
    data.scale = 1
    data.visible = true
    data.castShadow = true
    data.receiveShadow = false
    data.doubleSided = true
    
    geometry = Geometry.new
    geometry.uuid = format_uuid(surface.handle)
    geometry.type = 'Geometry'
    geometry.data = data.to_h
    geometries << geometry.to_h
    
    surface_user_data = UserData.new
    surface_user_data.handle = format_uuid(surface.handle)
    surface_user_data.name = surface.name.to_s
    surface_user_data.surfaceType = 'Shade'
    surface_user_data.constructionName = nil
    if surface.construction.is_initialized
      surface_user_data.constructionName = surface.construction.get.name.to_s
    end
    surface_user_data.spaceName = nil
    surface_user_data.thermalZoneName = nil
    if surface.space.is_initialized
      space = surface.space.get
      surface_user_data.spaceName = space.name.to_s
      if space.thermalZone.is_initialized
        surface_user_data.thermalZoneName = space.thermalZone.get.name.to_s
      end
    end
    surface_user_data.outsideBoundaryCondition = nil
    surface_user_data.outsideBoundaryConditionObjectName = nil
    surface_user_data.sunExposure = 'SunExposed'
    surface_user_data.windExposure = 'WindExposed'
    vertices = []
    surface.vertices.each do |v| 
      vertex = Vertex.new
      vertex.x = v.x
      vertex.y = v.y
      vertex.z = v.z
      vertices << vertex.to_h
    end
    surface_user_data.vertices = vertices
    user_datas << surface_user_data.to_h

    return [geometries, user_datas]
  end  

  def self.identity_matrix
    return [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
  end

  def self.build_scene(model)

    materials = build_materials
    
    object = Hash.new
    object[:uuid] = format_uuid(OpenStudio::createUUID)
    object[:type] = 'Scene'
    object[:matrix] = identity_matrix
    object[:children] = []
    
    # loop over all surfaces
    all_geometries = []
    model.getSurfaces.each do |surface|

      material = nil
      surfaceType = surface.surfaceType.upcase
      if surfaceType == 'FLOOR'
        material = materials[0]
      elsif surfaceType == 'WALL'
        material = materials[1]
      elsif surfaceType == 'ROOFCEILING'
        material = materials[2]    
      end
  
      geometries, user_datas = make_geometries(surface)
      geometries.each_index do |i| 
        geometry = geometries[i]
        user_data = user_datas[i]
        
        all_geometries << geometry

        scene_child = SceneChild.new
        scene_child.uuid = format_uuid(OpenStudio::createUUID) 
        scene_child.name = "#{surface.name.to_s} #{i}"
        scene_child.type = "Mesh"
        scene_child.geometry = geometry[:uuid]
        
        if i == 0
          scene_child.material = material[:uuid]
        else
          # sub surface, assign window 
          scene_child.material =  materials[3][:uuid]
        end
        
        scene_child.matrix = identity_matrix
        scene_child.userData = user_data
        object[:children] << scene_child.to_h
      end
      
    end
    
    # loop over all shading surfaces
    model.getShadingSurfaces.each do |surface|

      material = materials[4]    
  
      geometries, user_datas = make_shade_geometries(surface)
      geometries.each_index do |i| 
        geometry = geometries[i]
        user_data = user_datas[i]
        
        all_geometries << geometry

        scene_child = SceneChild.new
        scene_child.uuid = format_uuid(OpenStudio::createUUID) 
        scene_child.name = "#{surface.name.to_s} #{i}"
        scene_child.type = 'Mesh'
        scene_child.geometry = geometry[:uuid]
        scene_child.material = material[:uuid]
        scene_child.matrix = identity_matrix
        scene_child.userData = user_data
        object[:children] << scene_child.to_h
      end
      
    end    
    
    #light = AmbientLight.new
    #light.uuid = "#{format_uuid(OpenStudio::createUUID)}"
    #light.type = "AmbientLight"
    #light.color = "0xFFFFFF".hex
    #light.matrix = identity_matrix
    #object[:children] << light.to_h
      
    scene = Scene.new
    scene.geometries = all_geometries
    scene.materials = materials
    scene.object = object

    return scene
  end
  
  
end