extends Node

onready var playerMe = get_parent()
onready var headcam = playerMe.get_node('HeadCam')
onready var handleft = playerMe.get_node("HandLeft")
onready var handright = playerMe.get_node("HandRight")

onready var kinematic_body: KinematicBody = playerMe.get_node("KinematicBody")
onready var collision_shape: CollisionShape = playerMe.get_node("KinematicBody/CollisionShape")
onready var tail : RayCast = playerMe.get_node("KinematicBody/Tail")
onready var world_scale = ARVRServer.world_scale

onready var tiptouchray = get_node("/root/Spatial/HandObjects/MovePointThimble/TipTouchRay")

var player_radius = 0.25
var nextphysicsrotatestep = 0.0  # avoid flicker if done in _physics_process 
var velocity = Vector3(0.0, 0.0, 0.0)
var gravity = -30.0

export var walkspeed = 180.0
export var flyspeed = 250.0
export var drag_factor = 0.1

func _ready():
	handleft.connect("button_pressed", self, "_on_button_pressed")
	handleft.connect("button_release", self, "_on_button_release")
	print("ARVRinterfaces ", ARVRServer.get_interfaces())

var laserangleadjustmode = false
var laserangleoriginal = 0
var laserhandanglevector = Vector2(0,0)
var prevlaserangleoffset = 0

onready var audiobusrecordeffect = AudioServer.get_bus_effect(AudioServer.get_bus_index("Record"), 0)

func _on_button_pressed(p_button):
	if p_button == BUTTONS.VR_PAD:
		var joypos = Vector2(handleft.get_joystick_axis(0), handleft.get_joystick_axis(1))
		if abs(joypos.y) < 0.5 and abs(joypos.x) > 0.1:
			nextphysicsrotatestep += (1 if joypos.x > 0 else -1)*(22.5 if abs(joypos.x) > 0.8 else 90.0)

	laserangleadjustmode = (p_button == BUTTONS.VR_GRIP) and tiptouchray.is_colliding() and tiptouchray.get_collider() == handright.get_node("HeelHotspot")
	if laserangleadjustmode:
		laserangleoriginal = handright.get_node("LaserOrient").rotation.x
		laserhandanglevector = Vector2(handleft.global_transform.basis.x.dot(handright.global_transform.basis.y), handleft.global_transform.basis.y.dot(handright.global_transform.basis.y))
		
	if p_button == BUTTONS.VR_BUTTON_BY:
		audiobusrecordeffect.set_recording_active(true)
		print("Doing the recording ", audiobusrecordeffect)

	if p_button == BUTTONS.VR_GRIP:
		handleft.get_node("csghandleft").setpartcolor(4, "#00CC00")

		
func _on_button_release(p_button):
	if laserangleadjustmode:
		laserangleadjustmode = false
		handright.rumble = 0.0

	if p_button == BUTTONS.VR_BUTTON_BY:
		var recording = audiobusrecordeffect.get_recording()
		if recording != null:
			recording.save_to_wav("user://record3.wav")
			audiobusrecordeffect.set_recording_active(false)
			#print("Saved WAV file to: %s\n(%s)" % ["user://record3.wav", ProjectSettings.globalize_path("user://record3.wav")])
			print("end_recording ", audiobusrecordeffect)
			#handleft.get_node("AudioStreamPlayer3D").stream = recording
			#handleft.get_node("AudioStreamPlayer3D").play()
			print("recording length ", recording.get_data().size())
			print("fastlz ", recording.get_data().compress(File.COMPRESSION_FASTLZ).size())
			print("COMPRESSION_DEFLATE ", recording.get_data().compress(File.COMPRESSION_DEFLATE).size())
			print("COMPRESSION_ZSTD ", recording.get_data().compress(File.COMPRESSION_ZSTD).size())
			print("COMPRESSION_GZIP ", recording.get_data().compress(File.COMPRESSION_GZIP).size())
			playerMe.rpc("playvoicerecording", recording.get_data())

	if p_button == BUTTONS.VR_GRIP:
		handleft.get_node("csghandleft").setpartcolor(4, "#FFFFFF")


func _input(event):
	if event is InputEventKey and event.pressed:
		if event.is_action_pressed("lh_left") and not Input.is_action_pressed("lh_shift"):
			nextphysicsrotatestep += -22.5
		if event.is_action_pressed("lh_right") and not Input.is_action_pressed("lh_shift"):
			nextphysicsrotatestep += 22.5
		if event.is_action_pressed("ui_cancel"):
			if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if event.is_action_pressed("newboulder"):
			print("making new boulder")
			var markernode = preload("res://nodescenes/MarkerNode.tscn").instance()
			var boulderclutter = get_node("/root/Spatial/BoulderClutter")
			var nc = boulderclutter.get_child_count()
			markernode.get_node("CollisionShape").scale = Vector3(0.4, 0.6, 0.4) if ((nc%2) == 0) else Vector3(0.2, 0.4, 0.2)
			markernode.global_transform.origin = handright.global_transform.origin - 0.9*handright.global_transform.basis.z
			markernode.linear_velocity = -5.1*handright.global_transform.basis.z
			boulderclutter.add_child(markernode)

func _physics_process(delta):
	# Adjust the height of our player according to our camera position
	var player_height = max(player_radius, headcam.transform.origin.y + player_radius)
	collision_shape.shape.radius = player_radius
	collision_shape.shape.height = player_height - (player_radius * 2.0)
	collision_shape.transform.origin.y = (player_height / 2.0)
	#print(get_viewport().get_mouse_position(), Input.get_mouse_mode())
	var joypos = Vector2(handleft.get_joystick_axis(0), handleft.get_joystick_axis(1)) if handleft.get_is_active() else Vector2(0.0, 0.0)
	if playerMe.VRstatus == "quest":
		joypos = Vector2(0.0, 0.0)
		handleft.visible = true
	else:
		handleft.visible = playerMe.arvrinterface != null and handleft.get_is_active()
		if tiptouchray.is_colliding() != handright.get_node("LaserOrient/MeshDial").visible:
			handright.get_node("LaserOrient/MeshDial").visible = tiptouchray.is_colliding()
			handleft.get_node("csghandleft").setpartcolor(2, Color("222277") if tiptouchray.is_colliding() else Color("#FFFFFF"))

	if nextphysicsrotatestep != 0:
		var t1 = Transform()
		var t2 = Transform()
		var rot = Transform()
		t1.origin = -headcam.transform.origin
		t2.origin = headcam.transform.origin
		rot = rot.rotated(Vector3(0.0, -1, 0.0), deg2rad(nextphysicsrotatestep))
		playerMe.transform *= t2 * rot * t1
		nextphysicsrotatestep = 0.0
	
	var lhkeyvec = Vector2(0, 0)
	if Input.is_action_pressed("lh_forward"):
		lhkeyvec.y += 1
	if Input.is_action_pressed("lh_backward"):
		lhkeyvec.y += -1
	if Input.is_action_pressed("lh_left"):
		lhkeyvec.x += -1
	if Input.is_action_pressed("lh_right"):
		lhkeyvec.x += 1
	if not Input.is_action_pressed("lh_shift"):
		joypos += 0.6*60*delta*lhkeyvec
		
	if playerMe.arvrinterface == null:
		if Input.is_action_pressed("lh_shift") and lhkeyvec != Vector2(0,0):
			var vtarget = -headcam.global_transform.basis.z*20 + headcam.global_transform.basis.x*lhkeyvec.x*15*delta + Vector3(0, lhkeyvec.y, 0)*15*delta
			headcam.look_at(headcam.global_transform.origin + vtarget, Vector3(0,1,0))
			playerMe.rotation_degrees.y += headcam.rotation_degrees.y
			headcam.rotation_degrees.y = 0

	if tiptouchray.is_colliding() and tiptouchray.get_collider().get_name() == "GreenBlob":
		joypos += Vector2(0,1)

		
	if laserangleadjustmode and handleft.is_button_pressed(BUTTONS.VR_GRIP):
		var laserangleoffset = 0
		if tiptouchray.is_colliding() and tiptouchray.get_collider() == handright.get_node("HeelHotspot"):
			var laserhandanglevectornew = Vector2(handleft.global_transform.basis.x.dot(handright.global_transform.basis.y), handleft.global_transform.basis.y.dot(handright.global_transform.basis.y))
			laserangleoffset = laserhandanglevector.angle_to(laserhandanglevectornew)
		handright.rumble = min(1.0, abs(prevlaserangleoffset - laserangleoffset)*delta*290)
		if handright.rumble < 0.1:
			handright.rumble = 0
		else:
			prevlaserangleoffset = laserangleoffset
		handright.get_node("LaserOrient").rotation.x = laserangleoriginal + laserangleoffset
		
	elif handleft.is_button_pressed(BUTTONS.VR_GRIP) or Input.is_action_pressed("lh_fly"):
		if handleft.is_button_pressed(BUTTONS.VR_TRIGGER) or Input.is_action_pressed("lh_forward") or Input.is_action_pressed("lh_backward"):
			var curr_transform = kinematic_body.global_transform
			var flydir = handleft.global_transform.basis.z if handleft.get_is_active() else headcam.global_transform.basis.z
			if joypos.y < -0.5:
				flydir = -flydir
			velocity = flydir.normalized() * -delta * flyspeed * world_scale
			if handleft.is_button_pressed(BUTTONS.VR_PAD):
				velocity *= 3.0
			velocity = kinematic_body.move_and_slide(velocity)
			var movement = (kinematic_body.global_transform.origin - curr_transform.origin)
			kinematic_body.global_transform.origin = curr_transform.origin
			playerMe.global_transform.origin += movement
	
	else:
		var curr_transform = kinematic_body.global_transform
		var camera_transform = headcam.global_transform
		curr_transform.origin = camera_transform.origin
		curr_transform.origin.y = playerMe.global_transform.origin.y
		
		# now we move it slightly back
		var forward_dir = -camera_transform.basis.z
		forward_dir.y = 0.0
		if forward_dir.length() > 0.01:
			curr_transform.origin += forward_dir.normalized() * -0.75 * player_radius
		
		kinematic_body.global_transform = curr_transform
		
		# we'll handle gravity separately
		var gravity_velocity = Vector3(0.0, velocity.y, 0.0)
		velocity.y = 0.0
		
		# Apply our drag
		velocity *= (1.0 - drag_factor)
		
		if (abs(joypos.y) > 0.1 and tail.is_colliding()):
			var dir = camera_transform.basis.z
			dir.y = 0.0					
			velocity = dir.normalized() * (-joypos.y * delta * walkspeed * world_scale)
			#velocity = velocity.linear_interpolate(dir, delta * 100.0)		
		
		# apply move and slide to our kinematic body
		velocity = kinematic_body.move_and_slide(velocity, Vector3(0.0, 1.0, 0.0))
		
		# apply our gravity
		gravity_velocity.y += gravity * delta
		gravity_velocity = kinematic_body.move_and_slide(gravity_velocity, Vector3(0.0, 1.0, 0.0))
		velocity.y = gravity_velocity.y
		
		# now use our new position to move our origin point
		var movement = (kinematic_body.global_transform.origin - curr_transform.origin)
		playerMe.global_transform.origin += movement
		
		# Return this back to where it was so we can use its collision shape for other things too
		kinematic_body.global_transform.origin = curr_transform.origin

	var doppelganger = playerMe.doppelganger
	if is_inside_tree() and is_instance_valid(doppelganger):
		var positiondict = playerMe.playerpositiondict()
		positiondict["playertransform"] = Transform(Basis(-positiondict["playertransform"].basis.x, positiondict["playertransform"].basis.y, -positiondict["playertransform"].basis.z), 
													Vector3(doppelganger.global_transform.origin.x, positiondict["playertransform"].origin.y, doppelganger.global_transform.origin.z))
		if playerMe.bouncetestnetworkID != 0:
			playerMe.rpc_unreliable_id(playerMe.bouncetestnetworkID, "bouncedoppelgangerposition", playerMe.networkID, positiondict)
		else:
			doppelganger.setavatarposition(positiondict)

	if Tglobal.connectiontoserveractive:
		playerMe.rpc_unreliable("setavatarposition", playerMe.playerpositiondict())
	

