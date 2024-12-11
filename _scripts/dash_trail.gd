extends MeshInstance3D

@export_group("Trail Properties")
@export var trail_sections: int = 20  # Number of segments in the trail
@export var trail_length: float = 2.0  # How long the trail is in units
@export var trail_lifetime: float = 0.3  # How long each point lives in seconds
@export var trail_width: float = 1.975  # Width of the trail
@export var trail_color: Color = Color(0, 0.854902, 0.854902, 1.0)  # Color and transparency

var points: Array[Vector3] = []
var times: Array[float] = []
var current_time: float = 0.0
var is_active = false
var player: Node3D = null
var mesh_tool: MeshDataTool

func _ready():
    # Initialize arrays with default values
    points = []
    times = []
    for i in range(trail_sections):
        points.append(Vector3.ZERO)
        times.append(0.0)
    print("Points initialized:", points)
    clear_trail()
    
    # Create mesh
    var arrays = []
    arrays.resize(Mesh.ARRAY_MAX)
    
    var verts = PackedVector3Array()
    var uvs = PackedVector2Array()
    var indices = PackedInt32Array()
    var colors = PackedColorArray()
    
    # Create a quad strip for the trail
    for i in range(trail_sections):
        verts.append(Vector3.ZERO)  # Left vertex
        verts.append(Vector3.ZERO)  # Right vertex
        
        var t = float(i) / float(trail_sections-1)
        uvs.append(Vector2(t, 0))  # Left UV
        uvs.append(Vector2(t, 1))  # Right UV
        
        colors.append(trail_color)  # Left color
        colors.append(trail_color)  # Right color
        
        if i < trail_sections-1:
            var idx = i * 2
            indices.append(idx)
            indices.append(idx + 1)
            indices.append(idx + 2)
            indices.append(idx + 1)
            indices.append(idx + 3)
            indices.append(idx + 2)
    
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    
    mesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    
    # Create material
    var material = StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true
    material.albedo_color = trail_color
    material.no_depth_test = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show both sides
    material_override = material
    
    # Initialize mesh tool
    mesh_tool = MeshDataTool.new()
    mesh_tool.create_from_surface(mesh, 0)
    
    visible = false

func set_player(p: Node3D):
    player = p
    # Set local position to be at player's center height
    position = Vector3(0, 1.0, 0)
    # Make sure we're not visible initially
    visible = false

func _process(delta: float):
    if not is_active or not player:
        return
    
    current_time += delta
    update_trail()

func start_trail():
    if not player:
        return
        
    is_active = true
    visible = true
    clear_trail()
    # Initialize first point at local origin
    points[0] = Vector3.ZERO
    times[0] = current_time

func stop_trail():
    is_active = false
    visible = false

func clear_trail():
    if points.size() != trail_sections:
        points.resize(trail_sections)
        for i in range(trail_sections):
            points[i] = Vector3.ZERO
    if times.size() != trail_sections:
        times.resize(trail_sections)
        for i in range(trail_sections):
            times[i] = 0.0
    current_time = 0.0
    print("Trail cleared. Points:", points)

func update_trail():
    if not player:
        return
        
    # Shift points back
    for i in range(trail_sections-1, 0, -1):
        points[i] = points[i-1]
        times[i] = times[i-1]
    
    # Add new point at local origin
    points[0] = Vector3.ZERO
    times[0] = current_time
    
    # Update mesh vertices
    for i in range(trail_sections):
        var pos = points[i]
        if pos == Vector3.ZERO and i > 0:  # Skip uninitialized points except first point
            continue
            
        # Calculate fade based on time and position
        var time_alive = current_time - times[i]
        var life_factor = clamp(1.0 - (time_alive / trail_lifetime), 0.0, 1.0)
        var position_factor = 1.0 - (float(i) / float(trail_sections-1))
        var fade = life_factor * position_factor
        
        # Calculate trail position with offset
        var trail_pos = Vector3.BACK * (trail_length * (float(i) / float(trail_sections-1)))
        
        # Calculate right vector in local space
        var right = Vector3.RIGHT * (trail_width * fade)
        
        # Update vertices
        var idx = i * 2
        mesh_tool.set_vertex(idx, trail_pos + right)
        mesh_tool.set_vertex(idx + 1, trail_pos - right)
        
        # Set vertex colors for fade
        var color = trail_color
        color.a *= fade
        mesh_tool.set_vertex_color(idx, color)
        mesh_tool.set_vertex_color(idx + 1, color)
    
    mesh.clear_surfaces()
    mesh_tool.commit_to_surface(mesh)