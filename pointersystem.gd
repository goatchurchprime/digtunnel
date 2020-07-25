extends Spatial

# this has a pointer sphere added JGT
# (and a lot of other hacking)

# variables set by the Spatial.gd
var drawnfloor = null
var sketchsystem = null
var centrelinesystem =null
var nodeorientationpreview = null

var guipanel3d = null
var _is_activating_gui = false
var viewport_point = null

enum Buttons { VR_TRIGGER = 15, VR_PAD=14, VR_BUTTON_BY=1, VR_GRIP=2 }
onready var controller = get_parent()
onready var arvrcamera = get_node("../../ARVRCamera")
var distance = 50

var collision_mask = 14 

const OnePathNode = preload("res://nodescenes/OnePathNode.tscn")
const XCdrawing = preload("res://nodescenes/XCdrawing.tscn")
const XCnode = preload("res://nodescenes/XCnode.tscn")
				
var pointinghighlightmaterial = SpatialMaterial.new()
var selectedhighlightmaterial = SpatialMaterial.new()
var selectedpointerhighlightmaterial = SpatialMaterial.new()

var pointertarget = null
var pointertargetpoint = Vector3(0, 0, 0)
var pointertargetoriginy = 0.0
var selectedtarget = null
var gripbuttonpressused = false
var nodeorientationpreviewheldtransform = null


# set_materialoverride

onready var LaserSquare = get_node("../../../LaserSquare")
onready var LaserSpot = get_node("LaserSpot") 
onready var LaserSpike = get_node("LaserSpot/LaserSpike") 
onready var LaserShadow = get_node("LaserShadow") 

var laser_y = -0.05

onready var ARVRworld_scale = ARVRServer.world_scale

func set_collision_mask(p_new_mask):
	collision_mask = p_new_mask
	print("collision_maskcollision_maskcollision_mask ", collision_mask)
	if $Laser:
		$Laser/RayCast.collision_mask = collision_mask

func settextpanel(ltext, pos):
	var textpanel = sketchsystem.get_node("Centreline/TextPanel")
	if ltext != null:
		textpanel.get_node("Viewport/Label").text = ltext
		textpanel.global_transform.origin = pos + Vector3(0, 0.3, 0)
		textpanel.visible = true
	else:
		textpanel.visible = false

func _ready():
	get_parent().connect("button_pressed", self, "_on_button_pressed")
	get_parent().connect("button_release", self, "_on_button_release")
	print("LaserSquare ", LaserSquare)
	print("LaserSpot ", LaserSpot)
	pointinghighlightmaterial.albedo_color = Color(0.99, 0.20, 0.20, 1.0)
	pointinghighlightmaterial.flags_no_depth_test = true
	pointinghighlightmaterial.params_grow = true
	pointinghighlightmaterial.params_grow_amount = 0.02
	selectedhighlightmaterial.albedo_color = Color(0.92, 0.99, 0.13, 1.0)
	selectedpointerhighlightmaterial.albedo_color = Color(0.82, 0.99, 0.93, 1.0)
	selectedpointerhighlightmaterial.flags_no_depth_test = true
	selectedpointerhighlightmaterial.params_grow = true
	selectedpointerhighlightmaterial.params_grow_amount = 0.02
	
	# apply our world scale to our laser position
	$Laser.translation.y = laser_y * ARVRworld_scale
	
	# init our state
	print("in the pointer onready")
	$Laser.mesh.size.z = distance
	$Laser.translation.z = distance * -0.5
	$Laser/RayCast.translation.z = distance * 0.5
	$Laser/RayCast.cast_to.z = -distance

func setopnpos(opn, p):
	opn.global_transform.origin = p
	if opn.get_parent().get_name() == "OnePathNodes":
		opn.global_transform.origin = p + Vector3(0, 0.2, 0)
		opn.scale.y = opn.global_transform.origin.y
		sketchsystem.ot.copyopntootnode(opn)		
		
func onpointing(newpointertarget, newpointertargetpoint):
	if newpointertarget != pointertarget:
		if is_instance_valid(pointertarget) and pointertarget == guipanel3d:
			guipanel3d.guipanelreleasemouse()
		
		if is_instance_valid(pointertarget) and pointertarget.has_method("set_materialoverride"):
			pointertarget.set_materialoverride(selectedhighlightmaterial if pointertarget == selectedtarget else null)
			if pointertarget.global_transform.origin.y != pointertargetoriginy:
				sketchsystem.updateonepaths()

		pointertarget = newpointertarget
		if is_instance_valid(pointertarget):
			if pointertarget.has_method("set_materialoverride"):
				pointertarget.set_materialoverride(selectedpointerhighlightmaterial if pointertarget == selectedtarget else pointinghighlightmaterial)
				LaserSpot.visible = false
				LaserShadow.visible = true
				pointertargetoriginy = pointertarget.global_transform.origin.y
			elif pointertarget == guipanel3d:
				LaserSpot.visible = false
				LaserShadow.visible = false
			else:
				LaserSpot.visible = true
				LaserShadow.visible = (pointertarget.get_name() == "XCdrawingplane")
		else:
			LaserSpot.visible = false
			LaserShadow.visible = false
	pointertargetpoint = newpointertargetpoint
	if is_instance_valid(pointertarget) and pointertarget == guipanel3d:
		guipanel3d.guipanelsendmousemotion(pointertargetpoint, controller.global_transform, controller.is_button_pressed(Buttons.VR_TRIGGER))

	if LaserSpot.visible:
		LaserSpot.global_transform.origin = pointertargetpoint
	if LaserShadow.visible:
		LaserShadow.global_transform = Transform(Basis(), Vector3(pointertargetpoint.x, drawnfloor.global_transform.origin.y, pointertargetpoint.z))


func _on_button_pressed(p_button):
	print("pppp ", pointertargetpoint)
	if p_button == Buttons.VR_BUTTON_BY:
		var cameracontrollervec = controller.global_transform.origin - arvrcamera.global_transform.origin
		var ccaxvec = arvrcamera.global_transform.basis.x.dot(controller.global_transform.basis.z)
		var pswitchpos = arvrcamera.global_transform.origin + arvrcamera.global_transform.basis.x*0.15 + arvrcamera.global_transform.basis.y*0.1
		var pswitchdist = controller.global_transform.origin.distance_to(pswitchpos)
		print("cccctranslation  ", ccaxvec, "  ", pswitchdist)
		if ccaxvec > 0.85 and pswitchdist < 0.1:
			#print("    translation  ", controller.get_node("../ARVRCamera").translation, "  ", controller.get_node("../ARVRCamera").rotation_degrees)
			guipanel3d.clickbuttonheadtorch()
		else:
			guipanel3d.togglevisibility(controller.get_node("pointersystem").global_transform)
			
	if p_button == Buttons.VR_TRIGGER and is_instance_valid(pointertarget):
		print("clclc ", pointertarget.get_name(), "  filename:", pointertarget.get_filename(), " p:", pointertarget.get_parent())
		if pointertarget.has_method("jump_up"):
			pointertarget.jump_up()
			
		elif pointertarget == guipanel3d:
			pass  #this is processed elsewhere

		elif pointertarget == nodeorientationpreview:
			nodeorientationpreviewheldtransform = get_parent().global_transform.inverse()

		elif pointertarget.get_name() == "XCdrawingplane":
			var xcdrawing = pointertarget.get_parent()
			
			# drag node to new position on XCdrawingplane
			if controller.is_button_pressed(Buttons.VR_GRIP) and is_instance_valid(selectedtarget) and selectedtarget.get_parent().get_name() == "XCnodes":
				if selectedtarget.get_parent().get_parent() == xcdrawing:
					xcdrawing.movexcnode(selectedtarget, pointertargetpoint)
				else:
					selectedtarget.set_materialoverride(null)
					selectedtarget = null

				gripbuttonpressused = true
			
			# make new node on XCdrawingplane
			elif not controller.is_button_pressed(Buttons.VR_GRIP):
				pointertarget = xcdrawing.newxcnode(-1)
				pointertarget.global_transform.origin = pointertargetpoint
				xcdrawing.copyxcntootnode(pointertarget)
				if is_instance_valid(selectedtarget) and selectedtarget.get_parent().get_parent() == xcdrawing:
					sketchsystem.xcapplyonepath(selectedtarget, pointertarget)
				if is_instance_valid(selectedtarget) and selectedtarget.has_method("set_materialoverride"):
					selectedtarget.set_materialoverride(null)
					
				if controller.is_button_pressed(Buttons.VR_GRIP):
					selectedtarget = null
				else:
					selectedtarget = pointertarget
					selectedtarget.set_materialoverride(selectedpointerhighlightmaterial)


		elif pointertarget == drawnfloor:
			# drag node to new position on floor
			if controller.is_button_pressed(Buttons.VR_GRIP) and is_instance_valid(selectedtarget) and selectedtarget.has_method("set_materialoverride"):
				if selectedtarget.get_parent().get_name() == "OnePathNodes":
					setopnpos(selectedtarget, pointertargetpoint)
					sketchsystem.updateonepaths()
				elif selectedtarget.get_parent().get_name() == "DrawnStationNodes":
					setopnpos(selectedtarget, pointertargetpoint)
				gripbuttonpressused = true
				
			# new drawn station node on floor with centreline node already connected
			elif is_instance_valid(selectedtarget) and selectedtarget.get_parent().get_name() == "StationNodes":
				pointertarget = centrelinesystem.newdrawnstationnode()
				setopnpos(pointertarget, pointertargetpoint)
				pointertarget.stationname = selectedtarget.stationname
				selectedtarget.set_materialoverride(null)
				selectedtarget = null
				settextpanel(null, null)
				
			# new node on floor, with or without other node selected to connect to
			else:
				pointertarget = sketchsystem.newonepathnode(-1)
				# this is where we add the xcpath into its XCdrawing
				setopnpos(pointertarget, pointertargetpoint)
				if is_instance_valid(selectedtarget) and selectedtarget.get_parent().get_name() == "OnePathNodes":
					pointertarget.global_transform.origin.y = selectedtarget.global_transform.origin.y
					pointertarget.scale.y = pointertarget.global_transform.origin.y
					sketchsystem.ot.copyopntootnode(pointertarget)
					sketchsystem.applyonepath(selectedtarget, pointertarget)
					selectedtarget.set_materialoverride(null)
				else:
					pointertarget.global_transform.origin.y = 0.2
					pointertarget.scale.y = pointertarget.global_transform.origin.y
					sketchsystem.ot.copyopntootnode(pointertarget)
					if is_instance_valid(selectedtarget) and selectedtarget.has_method("set_materialoverride"):
						selectedtarget.set_materialoverride(null)
										
				if controller.is_button_pressed(Buttons.VR_GRIP):
					selectedtarget = null
				else:
					selectedtarget = pointertarget
					selectedtarget.set_materialoverride(selectedpointerhighlightmaterial)
				
					
		# clear selected target by selecting again
		# (we may reconsider deselection on second selection)
		elif pointertarget == selectedtarget:
			var selectedtargettype = selectedtarget.get_parent().get_name()			
			if selectedtargettype == "StationNodes":
				settextpanel(null, null)
			selectedtarget.set_materialoverride(pointinghighlightmaterial)
			if controller.is_button_pressed(Buttons.VR_GRIP):
				if selectedtargettype == "OnePathNodes":
					sketchsystem.removeonepathnode(selectedtarget)
				elif selectedtargettype == "DrawnStationNodes":
					selectedtarget.queue_free()
				elif selectedtargettype == "XCnodes":
					selectedtarget.get_parent().get_parent().removexcnode(selectedtarget)
				gripbuttonpressused = true
			selectedtarget = null
			
		# click on new selected target (connect from previous selected target)
		elif pointertarget.has_method("set_materialoverride"):
			var pointertargettype = pointertarget.get_parent().get_name()
			
			# connect from selected node if exists
			if is_instance_valid(selectedtarget) and selectedtarget.has_method("set_materialoverride"):
				var selectedtargettype = selectedtarget.get_parent().get_name()
				selectedtarget.set_materialoverride(null)
				if selectedtargettype == "StationNodes":
					settextpanel(null, null)
				if selectedtargettype == "OnePathNodes" and pointertargettype == "OnePathNodes":
					sketchsystem.applyonepath(selectedtarget, pointertarget)
				if selectedtargettype == "XCnodes" and pointertargettype == "XCnodes":
					sketchsystem.xcapplyonepath(selectedtarget, pointertarget)

			selectedtarget = pointertarget
			selectedtarget.set_materialoverride(selectedpointerhighlightmaterial)
			if pointertargettype == "StationNodes":
				settextpanel(selectedtarget.stationname, selectedtarget.global_transform.origin)
			elif pointertargettype == "DrawnStationNodes":
				settextpanel(selectedtarget.stationname, centrelinesystem.stationnodemap[selectedtarget.stationname].global_transform.origin)				
			elif pointertargettype == "OnePathNodes":
				pass
			elif pointertargettype == "XCnodes":
				selectedtarget.get_node("../../XCdrawingplane").visible = true
				selectedtarget.get_node("../../XCdrawingplane/CollisionShape").disabled = false
				
	# change height of pointer target
	if p_button == Buttons.VR_PAD:
		var left_right = controller.get_joystick_axis(0)
		var up_down = controller.get_joystick_axis(1)
		if abs(up_down) < 0.5 and abs(left_right) > 0.1 and is_instance_valid(pointertarget):
			var dy = (1 if left_right > 0 else -1)*(1.0 if abs(left_right) < 0.8 else 0.1)
			var pointertargettype = pointertarget.get_parent().get_name()
			if pointertargettype == "OnePathNodes":
				pointertarget.global_transform.origin.y = max(0.1, pointertarget.global_transform.origin.y + dy)
				pointertarget.scale.y = pointertarget.global_transform.origin.y
				sketchsystem.ot.copyopntootnode(pointertarget)
				nodeorientationpreview.global_transform.origin = pointertarget.global_transform.origin

			if pointertarget.get_name() == "XCdrawingplane":
				pointertarget.scale.y = max(0.1, pointertarget.scale.y + dy)
				pointertarget.scale.x = max(0.1, pointertarget.scale.x + dy)
				
			# raise the whole drawn floor case!
			if pointertargettype == "DrawnStationNodes":
				drawnfloor.global_transform.origin.y = drawnfloor.global_transform.origin.y + dy
				centrelinesystem.get_node("DrawnStationNodes").global_transform.origin.y = drawnfloor.global_transform.origin.y
			
	if p_button == Buttons.VR_GRIP:
		gripbuttonpressused = false

func _on_button_release(p_button):
	# cancel selection by squeezing and then releasing grip without doing anything in between
	if p_button == Buttons.VR_GRIP and not gripbuttonpressused:
		if is_instance_valid(selectedtarget) and selectedtarget.has_method("set_materialoverride"):
			selectedtarget.set_materialoverride(pointinghighlightmaterial if selectedtarget == pointertarget else null)
			selectedtarget = null
		elif is_instance_valid(pointertarget) and pointertarget.get_name() == "XCdrawingplane":
			pointertarget.visible = false
			pointertarget.get_node("CollisionShape").disabled = true
			pointertarget = null
		
	elif p_button == Buttons.VR_TRIGGER and (nodeorientationpreviewheldtransform != null):
		print("dosomethingwith nodeorientationpreview ", nodeorientationpreviewheldtransform)
		nodeorientationpreviewheldtransform = null

	# new drawing wall position made
	elif p_button == Buttons.VR_TRIGGER and is_instance_valid(selectedtarget) and is_instance_valid(pointertarget) and pointertarget.has_method("set_materialoverride") and pointertarget != selectedtarget:
		var vwall = pointertarget.global_transform.origin - selectedtarget.global_transform.origin
		var vwallmid = (pointertarget.global_transform.origin + selectedtarget.global_transform.origin)/2
		var vwall2 = Vector2(vwall.x, vwall.z)
		var drawingwallangle = -vwall2.angle()
		var vwallsca = vwall2.length()
		var xcdrawing = XCdrawing.instance()
		var otxcdIndex = sketchsystem.get_node("XCdrawings").get_child_count()
		xcdrawing.set_name("XCdrawing"+String(otxcdIndex))
		xcdrawing.otxcdIndex = otxcdIndex   # could use the name in the list to avoid the index number
		sketchsystem.get_node("XCdrawings").add_child(xcdrawing)
		xcdrawing.global_transform = Transform(Basis().rotated(Vector3(0,1,0), drawingwallangle), vwallmid)
		xcdrawing.get_node("XCdrawingplane").scale = Vector3(vwallsca/2.0+1.0, 3.0, 1.0)
			
func _process(_delta):
	if !is_inside_tree():
		return
	if nodeorientationpreviewheldtransform != null:
		var oiv = Vector3(0,1,0)   # direction of orientation preview we are dragging from
		var iv = get_parent().global_transform.basis.xform(nodeorientationpreviewheldtransform.basis.xform(oiv))
		var iv0 = iv.cross(Vector3(0, 0, 1)).normalized()
		if iv0.length_squared() == 0:
			iv0 = iv.cross(Vector3(1, 0, 0))
		var iv1 = iv0.cross(iv)
		# here could add the 3D push pull motions too
		nodeorientationpreview.global_transform = Transform(Basis(iv0, iv, iv1), sketchsystem.ot.nodepoints[selectedtarget.otIndex])
	elif $Laser/RayCast.is_colliding():
		onpointing($Laser/RayCast.get_collider(), $Laser/RayCast.get_collision_point())
	else:
		onpointing(null, null)
	
