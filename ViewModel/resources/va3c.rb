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

class Va3c

  Material = Struct.new(:uuid, :type, :color, :ambient, :emissive, :specular, :shininess, :opacity, :transparent, :wireframe, :side)
  GeometryData = Struct.new(:vertices, :normals, :uvs, :faces, :scale, :visible, :castShadow, :receiveShadow, :doubleSided)
  Geometry = Struct.new(:uuid, :type, :data)
  AmbientLight = Struct.new(:uuid, :type, :color, :matrix)
  SceneChild = Struct.new(:uuid, :name, :type, :geometry, :material, :matrix, :userData)
  SceneObject = Struct.new(:uuid, :type, :matrix, :children)
  Scene = Struct.new(:geometries, :materials, :object)
  
  def self.convert_model(model)
    scene = build_scene(model)

    # build up the json hash
    result = Hash.new
    result['metadata'] = { "version" => 4.3, "type" => "Object", "generator" => "OpenStudio" }
    result['geometries'] = scene.geometries
    result['materials'] = scene.materials
    result['object'] = scene.object
    
    return result
  end
  
  # format a uuid
  def self.format_uuid(uuid)
    return uuid.to_s.gsub("{","").gsub("}","")
  end
  
  # create a material
  def self.make_material(color, opacity)

    transparent = false
    if opacity < 1
      transparent = true
    end

    material = {:uuid => "#{format_uuid(OpenStudio::createUUID)}",
                :type => "MeshPhongMaterial",
                :color => "#{color}".hex,
                :ambient => "#{color}".hex,
                :emissive => "0x000000".hex,
                :specular => "0x808080".hex,
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
    
    materials << make_material("0x808080", 1) # floor
    materials << make_material("0xccb266", 1) # wall
    materials << make_material("0x994c4c", 1) # roof
    materials << make_material("0x66b2cc", 0.6) # window
    materials << make_material("0x954b01", 1) # all else
    
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
    geometry.type = "Geometry"
    geometry.data = data.to_h
    geometries << geometry.to_h
    
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
      geometry.type = "Geometry"
      geometry.data = data.to_h
      geometries << geometry.to_h
    end

    return geometries
  end

  def self.identity_matrix
    return [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
  end

  def self.build_scene(model)

    materials = build_materials
    
    object = Hash.new
    object[:uuid] = format_uuid(OpenStudio::createUUID)
    object[:type] = "Scene"
    object[:matrix] = identity_matrix
    object[:children] = []
    
    # loop over all surfaces
    all_geometries = []
    model.getSurfaces.each do |surface|

      material = nil
      surfaceType = surface.surfaceType.upcase
      if surfaceType == "FLOOR"
        material = materials[0]
      elsif surfaceType == "WALL"
        material = materials[1]
      elsif surfaceType == "ROOFCEILING"
        material = materials[2]    
      end

      geometries = make_geometries(surface)
      geometries.each_index do |i| 
        all_geometries << geometries[i]
        
        scene_child = SceneChild.new
        scene_child.uuid = format_uuid(OpenStudio::createUUID) # is this right?
        scene_child.name = format_uuid(OpenStudio::createUUID) # is this right?
        scene_child.type = "Mesh"
        scene_child.geometry = geometries[i][:uuid]
        
        if i == 0
          scene_child.material =  material[:uuid]
        else
          # sub surface, assign window 
          scene_child.material =  materials[3][:uuid]
        end
        
        scene_child.matrix = identity_matrix
        scene_child.userData = {}
        object[:children] << scene_child.to_h
      end
      
    end
    
    light = AmbientLight.new
    light.uuid = "#{format_uuid(OpenStudio::createUUID)}"
    light.type = "AmbientLight"
    light.color = "0xFFFFFF".hex
    light.matrix = identity_matrix
    object[:children] << light.to_h
      
    scene = Scene.new
    scene.geometries = all_geometries
    scene.materials = materials
    scene.object = object

    return scene
  end
  
  
end