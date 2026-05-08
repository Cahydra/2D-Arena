extends Node
"""
License: MIT License
Authur: Cahydra
Published: 2026/05/08
Version: INFDEV
Description: Main Multiplayer Logic



Structure:
	Introduction
	Goals & Limitations
	Setup guide
	General information & recommendations
	Functions
	Debugging



Introduction:
	This text was written to make multiplayer games easier to make.
	The following text assumes you know some basic networking terminology.
	Everything is client sided unless synced & replicated across the network.
	Ping is unavoidable so account for it.
	Remote Procedure Call (RPC) order is usually more important than how long they take to be received.
	Trust the server not the client, clients can and will lie about their data that they send.
	The server should always take initiative for important tasks & should have safe guards against lying clients.
	You can most likely convert this to work with any other multiplayer protocol.



Goals & Limitations:
	Goals:
		Easy multiplayer.
		Minimal overhead & settings to mess around with
	Limitations: 
		Bandwidth.
		Hardware speed.
		Multiplayer protocol.



Setup guide:
	Enable multiple instances inside Debug > Customize Run Instances > Enable Multiple Instances. 
	Requiers a minimum of 2 arguments to work: is_server & size_or_wait.
	Use standard UNIX double dashes (--) before passing command line arguments to activate setup.
	
	-- is_server size_or_wait port timeout (if no port or timeout is given then port defaults to 1090, timeout defaults to 30)
	-- true 20 1090 30 = Creates a server instance with max 20 clients listening on port '1090' with a client timeout of 30 seconds.
	-- false 0.5 1090 10 = Creates a client instance that waits 0.5 second then tries to connect to IP 'localhost' on port '1090' with a timeout of 10 seconds.



General information & recommendations:
	Server works best with scenes, nodes also work but only where they are mentioned.
	Scenes are the only thing you can spawn/delete/reparent.
	I do not recommend you spawn/delete/reparent nodes unless you know what you are doing. Because spawned/deleted/reparented nodes do not get sync automatically by Server.
	Matching scene trees is crucial for Remote Procedure Calls (RPC's) to work properly.
	Peer is ready after the ready_peer(peer_id) signal gets called Server side.
	
	
	Good to know:
		Do visual effects client-sided, this is smoother & better.
		Add role to your prints like this 'print(role)' to see which instance a function is getting called from.
		Get peer information with peers[peer_id].
	
	
	CoreID:
		All scenes are given a core identification number called 'CoreID'. These CoreID's hold the same scenes for everyone.
		This does two things:
			1. Accurately syncs scenes.
			2. Decreases bandwidth usage.
		
		Get CoreID from scene = node_register.get(Scene)
		Get scene from CoreID = core_register.get(CoreID)
	
	
	Sync scenes:
		To sync a scene use the 'Server.add( scene, spawn_place, synced_spawn_properties )' function.
		Example:
			var new_scene = SCENE.instantiate()
			#Syncs new_scene to everyone inside 'current_scene' with multiplayer authority 3 and with given properties.
			Server.add( new_scene, get_tree().current_scene, 3, { "property_name": property_value, ...} )
	
	
	Sync data:
		There are 3 types of syncing methods:
			1. Synced once when spawned.
			2. Synced every sync update.
			3. Synced whenever needed.
		Combining all these 3 methods gives the best results.
		Transform related spawn properties should be 'set_deferred' instead of 'set' inside 'spawn_scene'!
		Adjust or replace the default values according to your syncing needs.
		
		
		Sync once when spawned:
			1. spawn class scenes, only scenes with a certain class inside 'spawn_class_dict'.
			2. spawn custom properties, sync_spawn_properties( {Node: ['property_name', ...], ...} ) gets stored inside 'spawn_node_properties'.
			
			Scene spawns with values from 'spawn_class_dict' if its class matches a key inside it.
			If scene class matches a key inside 'spawn_class_dict' then it gets added to 'spawn_node_properties'.
			Adjust or replace keys inside 'spawn_class_dict' with your own values.
			Example:
				Sync Rigidbody3D's position and velocity, also sync my player position.
				spawn_class_dict = {
					"RigidBody3D": ["position", "linear_velocity"],
					Player: ["global_position"],
				}
		
		
		Sync every sync update:
			1. update class scenes, only scenes with a certain class inside 'update_class_dict'. (stored inside 'update_class_scenes')
			2. update node properties, any nodes inside 'update_node_properties'. (stored inside 'update_node_properties')
			
			Every sync update all scenes inside 'update_class_scenes' gets synced to clients & server.
			If scene class matches a key inside 'update_class_dict' then it gets added to 'update_class_scenes'.
			Adjust or replace keys inside 'update_class_dict' with your own values.
			Example:
				Sync Rigidbody3D's position and velocity, also sync MyCustomClass color value. (Scene has a script with the class_name MyCustomClass)
				update_class_dict = {
					"RigidBody3D": ["position", "linear_velocity"],
					MyCustomClass: ["my_custom_color"],
				}
	
	
	Parent scene vs child scene:
		'spawned scene'/'owner scene'/'parent scene' is a scene that was spawned and has no owner.
		'child scene'/'owned scene'/'child scene' is a scene that is owned by another scene which is typically a spawned scene, its owner is set to that scene as well.
	
	
	History:
		Server is forward synced meaning scenes are spawned in numbered order as shown below. (Reparented scenes get pushed to the bottom of history)
		Root (Root)
			World3D (Scene) <- 1
				Player (Scene) <- 2
					Item (Scene) <- 3
	
	
	Catch:
		Catches added scenes from 'add' for players that were not ready to receive them at the time.
		These are scenes that get added somewhere in the exact same moment that a new peer joins.
		Catch up is handled at the end of 'send_sync_order'.
	
	
	Terminology:
		Internet Protocol (IP)
		Remote Procedure Call (RPC)
		Multiplayer Protocol (MP)
		Maximum Transmission Unit (MTU)
		Local Area Network (LAN)
		Network Address Translation (NAT)
		Internet Service Provider (ISP)
	
	
	physics_process -> outbound sync data.
	sync_classes/sync_properties_UDP <- inbound sync data.
	
	get_multiplayer_authority() = Node multiplayer authority.
	multiplayer.get_unique_id() = Self multiplayer ID.
	
	Address = localhost
	Port = 1090
	Multiplayer Protocol = ENetMultiplayerPeer (maximum 4095 clients, 1392 MTU)
	
	
	Fixed input buttons:
		F10 = Windowed
		F11 = Full screen
		Number pad ON:
			0 - 9 = Debug information


Multiplayer functions:
	Function
		Description
	
	
	add( scene: Node, spawn_place: Node, authority: int = 1, properties: Dictionary = {} )
		Adds scene to sync order this syncs it to peers and new peers.
		Spawn scene with custom synced properties from scene "sync_properties_UDP = ["color","text"]"
	
	
	echo( function.bind(arguments, ...), peer_id: int )
		Calls function with arguments on everyone or peer_id.
	
	allow_echo( function: Callable/[function: Callable, ...] )
		Allows a function to echo outside of authority limits.
	
	
	forward( {Node: {"property_name": property_value, ...}, ...}, peer_id ).
		Syncs specified properties from Node to everyone by default or to a single client/server when specified. 
	
	
	sync_spawn_properties( {Node: ["property_name", ...], ...} )
		Syncs custom properties on nodes once when spawned.
	
	desync_spawn_properties( Node/[Node, ...] )
		Desyncs nodes from sync_node_properties.
	
	
	sync_update_properties( {Node: ["property_name", ...], ...} )
		Syncs specified properties from Node every physics update to everyone until Node gets desynced with 'desync_update_properties' or is deleted.
	
	desync_update_properties( Node/[Node, ...] )
		Desyncs Node that was previously synced with 'sync_update_properties'.
	
	
	start_multiplayer( is_server, address_or_size, port, timeout )
		Starts multiplayer.
	
	
	handle_rejection( rejection_reason: String )
		Called when a client gets disconnected/kicked/timed out/ or cant find the specified server.
	
	
	wait( time )
		To wait call 'await wait(time)' time is in seconds.
	
	
	kick_peer( peer_id, kick_reason, forced )
		Kicks peer id from server with a kick reason, if forced=true disconnects peer_id without sending a reason.



Debugging:
	Dont hesitate to reach out for help when you need it the most.
	
	Numbers on your numpad between 0 - 9 show various debug information in output console.
	
	use 'server.role' inside your prints to debug which instance this print came from.
	
	Keep in mind when printing many lines of text to console.exe can cause massive lag spikes.
	
	
	Missing CoreID's?:
		Debugger might throw warnings once upon joining a server about some missing CoreID's. These can be mostly ignored since its working as intended.
		However if Debugger keeps throwing warnings about missing CoreID's even after some time has passed then there is an issue somewhere.
	
	
	Scene edge cases:
		Currently Covered Edge Cases INFDEV
		+scene = parent scene
		-scene = child scene
		Check situations and edge cases:
		1. directly delete +scene. <- WORKS
		2. directly delete -scene. <- WORKS
		3. indirectly delete +scene by being inside another deleting +scene. <- WORKS with is_deleting
		4. indirectly delete -scene by being inside another deleting -scene. <- WORKS with is_deleting
		5. indirectly delete -scene by being inside a deleting node <- WORKS with is_deleting
		6. reparent +scene. <- WORKS
		7. reparent -scene. <- WORKS
		8. spawn +scene then reparent child -scene and delete +scene to make reparented -scene stand alone <- WORKS with stand alone
		9. indirectly delete a reparented -scene by being inside another deleting -scene. <- WORKS with is_deleting
		10. delete an original parent node with a reparented scene attached to it, should turn 10 Empty to stand alone <- WORKS with stand alone
		11. reparent two consecutive -scenes and delete the parent -scene <- WORKS with stand_alone_scene.set_owner(null)
	
	PERFORMANCE TEST
	var start_time: int = Time.get_ticks_msec()
	for index: int in 10000:
	print("Time= ",Time.get_ticks_msec()- start_time,"ms")
	
	BYTE SIZE TEST
	print("Bytes= ",var_to_bytes().size())
"""
#ALERT,ATTENTION,CAUTION,CRITICAL,DANGER,SECURITY
#BUG,DEPRECATED,FIXME,HACK,TASK,TBD,TODO,WARNING
#INFO,NOTE,NOTICE,TEST,TESTING

const version: StringName = &'INFDEV'

##Multiplayer protocol
var multiplayer_protocol: ENetMultiplayerPeer = ENetMultiplayerPeer.new()

##Maximum Transmission Unit, size in bytes.
const MTU: int = 1392##ENetMultiplayerPeer MTU.


##Time taken before stopping or moving onto something else.
##Maxes out at 30.0 seconds and no smaller than 1.0 seconds.
var timeout: float = 10.0:
	set(new_time): timeout = clampf(new_time, 1.0, 30.0)

## Peers data.
var peers: Dictionary[int,Dictionary] = {1: {&'MTU': MTU, &'ready': true}}##{peer_id: {data dictionary}, ...}


#CoreID's are generated from 'new_coreid'.
##core_register[CoreID] = Node
var core_register: Dictionary[int,Node] = {}#{CoreID: Node, ...}
##node_register[ Node ] = CoreID
var node_register: Dictionary[Node,int] = {}#{Node: CoreID, ...}


##If the connection is alive or not.
var is_alive: bool = false:
	set(value):
		is_alive = value
		if is_alive: accepted.emit()


##Role as string.
var role: String:
	get():
		if is_alive: return 'Server' if multiplayer.is_server() else 'Client'
		else: return 'Role Not Assigned'


##Multiplayer ID.
var id: int:
	get(): return multiplayer.get_unique_id()


##Allows functions to be called outside their original authority, used by allow_echo.
var echoable_functions: Dictionary = {}##{Node: ['func', ...], ...}


##If an original parent is deleting then all of its child scenes that were reparented from it with become stand alone?
var original_parents: Dictionary = {}##{original_parent: [reparented owned scenes]}
var stand_alone_scenes: Dictionary = {}##{original_parent: {reparented owned scene's child scenes: null, child_scene: null}}


##Logs all relevant changes so joining clients get correct sync data about scenes.
##History works on a step by step basis.
var history: Dictionary = {}


##Holds isolated peer sync data that is vital for multiplayer functionality.
var isolated_classes: Dictionary = {}##{peer_id: {NodePath: [Transform3D, ...], ...}, ...}
var isolated_properties: Dictionary = {}##{peer_id: {NodePath: {'property': value, ...}, ...}, ...}


##Syncs class properties every sync update. Scenes with these classes gets added to update_class_scenes.
var update_class_dict: Dictionary = {
	#'RigidBody3D': ['global_transform','linear_velocity','angular_velocity'],
	Player: ['transform'],
}
##Stores scenes sorted by update_class_dict NOTE: Not pleased with this comment.
var update_class_scenes: Dictionary = {}##{Scene: null, ...}


##Syncs node properties every sync update.
var update_node_properties: Dictionary = {}##{CoreID: {'inner_path': ['property_name', ...], ...}, ...}


##ALERT Transform related spawn properties should be 'set_deferred' instead of 'set' inside 'spawn_scene'!
##Sync spawn properties
##Syncs scene class properties once when spawned.
var spawn_class_dict: Dictionary = {##{'Class': ['property_name', ...], ...}
	Player: ['transform'],
	Pistola2D: ['transform','bullets','cool_down'],
	Rifle2D: ['transform','bullets','cool_down'],
}

##Holds custom node spawn properties, added from 'add' or 'sync_spawn_properties'.
var spawn_node_properties: Dictionary[Node,PackedStringArray] = {}##{Node: ['property_name', ...], ...}


##Hook up a custom validating function for further peer validating needs: Server.validating.connect(advanced_validation)
signal validating(peer_id: int)##Emitted after basic server validation in server validate.
signal ready_peer(peer_id: int)##Emitted when the peer is ready after sync order in server.send_sync_order
signal rejected(reason: String)##Emitted when disconnected from a server.
signal accepted()##Emitted after starting or joining a server.


##Setup & signals
func _ready() -> void:
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(server_connected)
	multiplayer.server_disconnected.connect(server_disconnected)
	var cmdline_user_args: PackedStringArray = OS.get_cmdline_user_args()
	
	##Setup, requires a minimum of 2 arguments: is_server & size_or_wait.
	if cmdline_user_args.size() >= 2:
		var port: int = int(cmdline_user_args.get(2)) if cmdline_user_args.size() >= 3 else 1090
		var timeout_time: float = float(cmdline_user_args.get(3)) if cmdline_user_args.size() >= 4 else 30.0
		
		if string_to_bool(cmdline_user_args.get(0)):##Server
			start_multiplayer(true, cmdline_user_args.get(1), port, timeout_time)
		else:##Client
			await wait(float(cmdline_user_args.get(1)))
			start_multiplayer(false, 'localhost', port, timeout_time)


##Fixed key locations.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		#region FIXED BUTTONS
		if Input.is_key_pressed(KEY_F11):##Fullscreen on F11
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		if Input.is_key_pressed(KEY_F10):##Windowed on F10
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		#endregion
		
		##DEBUG
		match event.keycode:
			4194438:## 0
				print("\n\n"+role+" CoreID's")
				for core_id: int in core_register.keys():
					print(
						"\n",role," -> ",core_id," = ",core_register[core_id],
						"\n",role," -> ",core_register[core_id]," = ",node_register[core_register[core_id]]
					)
			4194439:## 1
				print("\n"+role+" peers= ",peers)
			4194440:## 2
				print("\n"+role+" history= ",history)
			4194441:## 3
				print("\n"+role+" InputMap= ",InputMap.get_actions())
			4194442:## 4
				print("\n"+role+" update_node_properties= ",update_node_properties)
			4194443:## 5
				print("\n"+role+" update_class_scenes= ",update_class_scenes)
			4194444:## 6
				print("\n"+role+" echoable_functions= ",echoable_functions)
			4194445:## 7
				print("\n"+role+" spawn_node_properties= ",spawn_node_properties)
			4194446:## 8
				print("\n"+role+" isolated_classes= ",isolated_classes)
			4194447:## 9
				print("\n"+role+" isolated_properties= ",isolated_properties)


##MAIN SYNC-LOOP, syncs properties to server & clients.
func _physics_process(_delta: float) -> void:
	##return if we should not sync or not connected to a server
	if !(can_sync() or is_alive): return
	
	isolated_classes.clear()
	isolated_properties.clear()
	
	##Gather up synced scenes by authority like so: {authority: {synced class: [class data, ...], ...}, ...}
	##Create isolated classes
	if update_class_scenes.size() >0:
		for scene: Node in update_class_scenes.keys():
			if !is_instance_valid(scene):
				push_warning("\n"+role+" invalid synced update scene")
				update_class_scenes.erase(scene)
				continue
			
			if !scene.is_inside_tree(): continue##Please dont spam my debugger with nonsense thanks.
			
			##Client checks
			if !multiplayer.is_server():
				if !scene.is_multiplayer_authority(): continue#Sync if client is multiplayer authority over scene.
			
			##Property data in array form.
			var sync_package: Array = []
			
			##Gather property value information from update_class_dict[scene.class]
			for property: String in update_class_dict[get_script_or_class(scene)]: sync_package.append(scene.get(property))
			#for property: String in update_class_dict[scene.get_class()]: sync_package.append(scene.get(property))
			#print("sync_package= ",scene.get_path()," = ",sync_package)
			
			##Sets isolated scenes based on multiplayer authority.
			if !isolated_classes.has(scene.get_multiplayer_authority()): isolated_classes[scene.get_multiplayer_authority()] = {}
			
			##This divides synced scenes based on their multiplayer authority
			isolated_classes[scene.get_multiplayer_authority()][scene] = sync_package
	
	
	##Create isolated properties
	if update_node_properties.size() >0:
		#print("\n",id," update_node_properties= ",update_node_properties)
		for CoreID: int in update_node_properties.keys():
			#if !is_instance_valid(node): update_node_properties.erase(node); continue##Fail safe for invalid nodes.
			#print("CoreID= ",CoreID)
			var CoreNode: Node = core_register[CoreID]
			#print("CoreID Authority= ",CoreNode.get_multiplayer_authority())
			
			if !CoreNode.is_inside_tree(): continue##Please dont spam my debugger with nonsense thanks.
			
			##Client checks
			if !multiplayer.is_server():
				if !CoreNode.is_multiplayer_authority(): continue#Sync if client is multiplayer authority over scene.
			
			
			##Build up the sync packet starting from CoreID.
			var packet: Dictionary = {CoreID: {}}
			
			
			for inner_path: String in update_node_properties[CoreID].keys():
				#print("inner_path= ",inner_path)
				#print("Properties to sync= ",update_node_properties[CoreID][inner_path])
				
				var inner_node: Node = get_node_or_null(str(CoreNode.get_path())+ inner_path)
				#print("inner_node= ",inner_node)
				
				packet[CoreID][inner_path] = {}
				for property_name: String in update_node_properties[CoreID][inner_path]: packet[CoreID][inner_path][property_name] = inner_node.get(property_name)##Gather up property data.
			
			
			#print("Packet= ",packet)
			##Packet = {Figure|31: {"/Viewmodel": {"global_rotation": Vector3(...), ...}, ...}, ...}
			##isolated_properties = {1: {Figure|31: {"/Viewmodel": {"global_rotation": Vector3(...), ...}, ...}, ...}, ...}
			
			isolated_properties[CoreNode.get_multiplayer_authority()] = packet
			#print("isolated_properties= ",isolated_properties)
	
	#print("\n")
	#print("isolated classes= ",isolated_classes)
	#print("isolated properties= ",isolated_properties)
	
	##NOTE I could combine these packet limiters together by changing some input values?
	##DISPATCH SYNCED VALUES TO CLIENTS/SERVER
	if multiplayer.is_server():##Server side
		##For every peer do
		##Gather up synced classes from isolated_classes that does not come from the same peer/authority
		##Then we loop through every class inside it
		##That do not go above current peer MTU size
		#print("\nServer isolated properties= ",isolated_properties)
		for peer_id: int in multiplayer.get_peers():
			#print(peer_id," peer is ready?= ",peers[peer_id][&'ready'])
			if peers[peer_id][&'ready']:##Peer is ready to receive?
				var peer_MTU: int = peers[peer_id][&'MTU']
				var class_packet: Dictionary = {}
				var packet: Dictionary = {}
				#print("\npeer id= ",peer_id)
				#print("peer MTU= ",peer_MTU)
				
				##For every isolated class by authority
				for authority: int in isolated_classes.keys():
					if authority != peer_id:##If authority is not the same as peer
						for synced_class_scene: Node in isolated_classes[authority]:
							#print("\nsynced class= ",synced_class_scene," : ",isolated_classes[authority][synced_class_scene])
							##TODO-later Find an efficent way to check new packet size.
							var next_packet: Dictionary = {node_register[synced_class_scene]: isolated_classes[authority][synced_class_scene]}.merged(class_packet)
							
							##if new packet size > peer MTU size then
							if var_to_bytes(next_packet).size() > peer_MTU:
								sync_classes.rpc_id(peer_id, class_packet)##Send full packet
								class_packet.clear()##Clear full packet
							
							##Add to packet
							class_packet[node_register[synced_class_scene]] = isolated_classes[authority][synced_class_scene]
				
				##Send the remaining data packets if there are any left.
				if class_packet.size() != 0: sync_classes.rpc_id(peer_id, class_packet)
				
				##isolated_properties Packet = {Figure|31: {"/Viewmodel": {"global_rotation": Vector3(...), ...}, ...}, ...}
				
				##For every isolated property by authority
				for authority: int in isolated_properties.keys():
					if authority != peer_id:##If authority ID is not the same as peer ID
						for CoreID: int in isolated_properties[authority]:
							#print("CoreID= ",CoreID)
							#print("Data= ",isolated_properties[authority][CoreID])
							##NOTE: Put everything from CoreID into one packet for now.
							###Packet = {CoreID: {"inner_path": {"property_name": property, ...}, ...}, ...}
							var next_packet: Dictionary = { CoreID: isolated_properties[authority][CoreID] }.merged(packet)
							
							#print("Next packet= ",next_packet)
							###if predicted size > peer MTU size then
							if var_to_bytes(next_packet).size() > peer_MTU:
								sync_properties_UDP.rpc_id(peer_id, packet)##Send full packet
								packet.clear()##Clear full packet
							
							
							###Add to packet
							packet[CoreID] = isolated_properties[authority][CoreID]
							#print("Packet= ",packet)
				##Send the remaining data packets if there are any left.
				if packet.size() != 0: sync_properties_UDP.rpc_id(peer_id, packet)
	else:##Client side
		#print("isolated classes= ",isolated_classes)
		#print("\nClient ",id," isolated properties= ",isolated_properties)
		var peer_id: int = multiplayer.get_unique_id()
		var server_MTU: int = peers[1][&'MTU']
		
		var class_packet: Dictionary = {}
		var packet: Dictionary = {}
		
		
		if isolated_classes.has(peer_id):
			##For every isolated class by client authority
			for synced_class_scene: Node in isolated_classes[peer_id].keys():
				#print("\nsynced class= ",synced_class_scene," : ",isolated_classes[peer_id][synced_class_scene])
				##TODO-later Find a more efficent way to check new packet size.
				var next_packet: Dictionary = {node_register[synced_class_scene]: isolated_classes[peer_id][synced_class_scene]}.merged(class_packet)
				
				
				##if new packet size > peer MTU size then
				if var_to_bytes(next_packet).size() > server_MTU:
					sync_classes.rpc_id(1, class_packet)##Send full packet
					class_packet.clear()##Clear full packet
				
				##Add to packet
				class_packet[node_register[synced_class_scene]] = isolated_classes[peer_id][synced_class_scene]
			
			##Send the remaining data packets if there are any left.
			if class_packet.size() != 0: sync_classes.rpc_id(1, class_packet)
		
		##Send the remaining data packets if there are any left.
		if class_packet.size() != 0: sync_classes.rpc_id(1, class_packet)
		
		
		##For every isolated property by authority
		for authority: int in isolated_properties.keys():
			for CoreID: int in isolated_properties[authority]:
				#print("CoreID= ",CoreID)
				#print("Data= ",isolated_properties[authority][CoreID])
				##NOTE: Put everything from CoreID into one packet for now.
				###Packet = {CoreID: {"inner_path": {"property_name": property, ...}, ...}, ...}
				var next_packet: Dictionary = { CoreID: isolated_properties[authority][CoreID] }.merged(packet)
				
				#print("Next packet= ",next_packet)
				###if predicted size > peer MTU size then
				if var_to_bytes(next_packet).size() > server_MTU:
					sync_properties_UDP.rpc_id(1, packet)##Send full packet
					packet.clear()##Clear full packet
				
				
				###Add to packet
				packet[CoreID] = isolated_properties[authority][CoreID]
				#print(role+" Packet= ",packet)
		
		##Send the remaining data packets if there are any left.
		if packet.size() != 0: sync_properties_UDP.rpc_id(1, packet)


##Syncs scene classes.
##Client syncs all classes sent by server
##Server only syncs classes sender has authority over.
##Server.sync_classes( {CoreID: [property_value, ...], ...} )
@rpc("any_peer","unreliable")
func sync_classes(synced_class_data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	#if !multiplayer.is_server():
	#	print("\n"+role+" sync_classes= ",sender_id," | ",synced_class_data)
	
	##Clients only receives server sync requests.
	if !multiplayer.is_server() and sender_id != 1: return
	
	for CoreID: int in synced_class_data.keys():#print("core_register= ",core_register)
		var node: Node = core_register.get(CoreID)
		if node != null:##Synced node exists
			#if !multiplayer.is_server(): print(node," | ",node.get_multiplayer_authority())
			
			##Safety checks.
			if multiplayer.is_server():##Server
				##If synced node authority does not match sender id then continue
				if node.get_multiplayer_authority() != sender_id: continue
			
			##Sync properties
			var properties: PackedStringArray = update_class_dict[get_script_or_class(node)]#Gets properties from update_class_dict[class]
			for index: int in properties.size():#print(role+" property= ",properties[index]," : ",synced_class_data[CoreID][index])
				node.set(properties[index], synced_class_data[CoreID][index])
		else:
			##NOTE: Might throw one warning per CoreID on start.
			push_warning(role+" could not sync missing CoreID!= ",CoreID,
			"\nCommon issues: Syncing node before ",role," has time to register that CoreID or Missing to sync CoreID.
			synced classes data= ",synced_class_data)


##NOTE Monitor security checks for these functions.
##Syncs properties unreliably & fast.
##Server.sync_properties_UDP( {CoreID: {'inner_path': {'property_name': property, ...}, ...}, ...} / {NodePath: {'property_name': property, ...}, ...} )
@rpc("any_peer","unreliable")
func sync_properties_UDP(sync_properties_data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var node_properties: Dictionary = {}
	
	#if multiplayer.is_server():
	#print("\n"+role+" sync_properties_UDP! sender_id= ",sender_id," | ",sync_properties_data)
	##Syncs properties in 2 steps
	##Step 1: Extract/Unpack data
	##Step 2: Sync/Apply data
	
	##Extract nodes from sync_properties_data
	for key in sync_properties_data.keys():##key = CoreID/NodePath
		if key is int:##CoreID, contains inner path to a node. print("Node from CoreID= ",core_register.get(key))
			for inner_path: String in sync_properties_data[key].keys():
				#print("inner path= ",inner_path)
				
				##Make sure CoreID's Node is not null!
				var core_node: Node = core_register.get(key)
				if core_node != null:
					#print("core node= ",core_node)
					#print("core path= ",core_node.get_path())
					#print("inner path= ",inner_path)
					#print("Complete path= ",str(core_node.get_path())+ inner_path)
					var inner_node: Node = get_node_or_null(str(core_node.get_path())+ inner_path)
					#print("inner Node= ",inner_node)
					
					node_properties[inner_node] = sync_properties_data[key][inner_path]
				else: push_warning(role+" CoreID not found!= ",key)
		else:##NodePath
			node_properties[get_node_or_null(key)] = sync_properties_data[key]##NOTICE: Common Errors: the given node path is a String instead of NodePath.
	#if multiplayer.is_server():
	#print("\n"+role+" sync node_properties= ",node_properties)
	
	##Apply properties on nodes
	for node: Node in node_properties.keys():#print("Node= ",node)
		if node != null:
			#print(node," | Key= ",node_properties[node])
			##If Key is Null then Delete node.
			if node_properties[node] == null:
				#print_debug("Deleted node found!= ",node)
				node.queue_free()
				continue
			
			
			for property: String in node_properties[node].keys():
				if property == '0id' && sender_id == 1:##Set CoreID but only when sender_id is the server.
					register_set(node, node_properties[node][property])
				
				node.set(property, node_properties[node][property])
				#if multiplayer.is_server():
				#print(role," set property= ",property," | ",node_properties[node][property]," on ",node.name)
		else:
			push_warning(role+" Node not found! sync property data= ",sync_properties_data)##NOTICE: Common Errors: syncing a server/client side only scene when not supposed to.


##Syncs properties reliably & slow.
##Server.sync_properties_TCP( {CoreID: {'inner_path': {'property_name': property, ...}, ...}, ...} / {NodePath: {'property_name': property, ...}, ...} )
@rpc("any_peer","reliable")
func sync_properties_TCP(sync_properties_data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var node_properties: Dictionary = {}
	#print("\n"+role+" sync_properties_TCP= ",sync_properties_data," | ",sender_id)
	##Syncs properties in 2 steps
	##Step 1: Extract/Unpack data
	##Step 2: Sync/Apply data
	
	##Extract nodes from sync_properties_data
	for key in sync_properties_data.keys():##key = CoreID/NodePath
		if key is int:##CoreID, contains inner path to a node. print("Node from CoreID= ",core_register.get(key))
			for inner_path: String in sync_properties_data[key].keys():#print("inner path= ",inner_path)
				
				##Make sure CoreID's Node is not null!
				var core_node: Node = core_register.get(key)
				if core_node != null:
					var inner_node: Node = get_node_or_null(str(core_node.get_path())+ inner_path)#print("inner Node= ",inner_node)
					
					node_properties[inner_node] = sync_properties_data[key][inner_path]
				else: push_warning(role+" CoreID not found!= ",key)
		else:##NodePath
			node_properties[get_node_or_null(key)] = sync_properties_data[key]##NOTE: Common Errors: the given node path is a String instead of NodePath.
	##print("\nnode_properties= ",node_properties)
	
	##Apply properties on nodes
	for node: Node in node_properties.keys():#print("Node= ",node)
		if node != null:
			##If Key is Null then Delete node.
			if node_properties[node] == null:
				print_debug("Deleted!= ",node)
				node.queue_free()
				continue
			
			
			for property: String in node_properties[node].keys():
				if property == '0id' && sender_id == 1:##Set CoreID but only when sender_id is the server.
					register_set(node, node_properties[node][property])
				
				node.set(property, node_properties[node][property])##print("property= ",property," | ",node_properties[node][property])
		else: push_warning(role+" 'Null' Node not found! sync property data= ",sync_properties_data)##NOTE: Common Errors: trying to sync a server or client side only scene!


##ALERT Server side!
##Syncs custom spawn properties on nodes.
##Server.sync_spawn_properties( {Node: ["property_name", ...], ...} )
func sync_spawn_properties(properties: Dictionary[Node,PackedStringArray], overwrite: bool = true) -> void:
	if !multiplayer.is_server(): return
	#print("\n"+role+" sync_spawn_properties! properties= ",properties)
	spawn_node_properties.merge(properties, overwrite)


##ALERT Server side!
##Desyncs custom spawn properties from nodes.
##Server.desync_spawn_properties( Node/[Node, ...] )
func desync_spawn_properties(desync_nodes) -> void:
	if !multiplayer.is_server(): return
	#print("\n"+role+" desync_spawn_properties= ",desync_nodes)
	if desync_nodes is Array:
		for desynced_node: Node in desync_nodes:
			spawn_node_properties.erase(desynced_node)
	elif desync_nodes is Node:
		spawn_node_properties.erase(desync_nodes)


##Syncs node properties every sync update.
##Server.sync_update_properties( {Node: ["property_name", ...], ...} )
func sync_update_properties(properties: Dictionary[Node,PackedStringArray]) -> void:
	#print("\n"+role+" sync_update_properties= ",properties)
	for node: Node in properties.keys():#print("Node= ",node)
		var CorePath: Dictionary = get_corepath(node)
		##Re-use or create a new CoreID data container.
		if update_node_properties.has(CorePath[true]): update_node_properties[CorePath[true]][CorePath[false]] = properties[node]
		else: update_node_properties[CorePath[true]] = {CorePath[false]: properties[node]}


##Desync node properties.
##Server.desync_update_properties( Node/[Node, ...] )
func desync_update_properties(desync_nodes) -> void:
	#print("\n"+role+" desync_update_properties= ",desync_nodes)
	if desync_nodes is Array:
		for desync_node: Node in desync_nodes:#print("desync_node= ",desync_node)
			var CorePath: Dictionary = get_corepath(desync_node)
			update_node_properties[CorePath[true]].erase(CorePath[false])##Erase synced property value
			if update_node_properties[CorePath[true]].size() == 0: update_node_properties.erase(CorePath[true])##Erase entry if empty 
	elif desync_nodes is Node:
		var CorePath: Dictionary = get_corepath(desync_nodes)
		update_node_properties[CorePath[true]].erase(CorePath[false])##Erase synced property value
		if update_node_properties[CorePath[true]].size() == 0: update_node_properties.erase(CorePath[false])##Erase entry if empty 


##Syncs properties on Nodes to everyone or to given peer_id.
##Server.forward( {Node: {"property_name": property_value, ...}, ...}, peer_id )
func forward(properties: Dictionary[Node,Dictionary], peer_id: int = 0) -> void:
	#print("\n"+role+" Forward! properties= ",properties,"| peer_id= ",peer_id)
	##First set properties then sync properties
	var packet: Dictionary = {}
	
	##Set properties on nodes.
	for node: Node in properties.keys():
		#print("Node= ",node)
		
		var CoreNode: Node = get_closest_path(node)
		#print("Closest CoreNode to node= ",CoreNode)
		
		var inner_path: String = substr(node.get_path(), CoreNode.get_path())
		#print("inner_path= ",inner_path)
		
		##Add CoreID with inner_path to packet
		packet[node_register[CoreNode]] = {inner_path: {}}
		
		
		for property_name: String in properties[node].keys():
			#print("property name= ",property_name)
			#print("property value= ",properties[node][property_name])
			packet[node_register[CoreNode]][inner_path][property_name] = properties[node][property_name]##Set property in packet
			node.set(property_name, properties[node][property_name])##Set property in node
	
	#print("Packet= ",packet)
	if peer_id == 0: sync_properties_TCP.rpc(packet) 
	else: sync_properties_TCP.rpc_id(peer_id, packet)


##ALERT Server side!
##Server.allow_echo( function: Callable / [function: Callable, ...] )
func allow_echo(echos) -> void:
	if !multiplayer.is_server(): return
	#print(role+" allow_echo= ",echos)
	var object: Object = null
	if echos is Array:##echos = [function: Callable, function: Callable]
		for comble: Callable in echos:
			object = comble.get_object()
			
			if echoable_functions.has(object): echoable_functions[object].append(comble.get_method())
			else: echoable_functions[object] = PackedStringArray([echos.get_method()])
	elif echos is Callable:##echos = function: Callable
		object = echos.get_object()
		
		if echoable_functions.has(object): echoable_functions[object].append(echos.get_method())
		else: echoable_functions[object] = PackedStringArray([echos.get_method()])


##ALERT To echo outside authority limits add 'Server.allow_echo(function)' from a server side script.
##NOTE Authority is 1 by default, even for locally spawned scenes.
##Echos a function to clients & server or single peer id. If smooth=true then the client will imedietly call the function instead of waiting for it to be received in receiver.
##Server.echo.bind( function.bind(arguments), peer_id ) -> function
func echo(function: Callable, peer_id: int = 0) -> Callable:
	#print("\n"+role+" echo= ",function," | ",function.get_bound_arguments()," | ",function.get_object()," | peer_id= ",peer_id)
	var object: Object = function.get_object()
	##Make sure we can call function.
	if not object is Node: push_error(role," echo, function object not found!"); return function
	
	var method: StringName = function.get_method()
	var arguments: Array = function.get_bound_arguments()
	var CorePath: Dictionary = get_corepath(object)
	
	##Broadcast
	if multiplayer.is_server(): broadcast(method, arguments, CorePath, peer_id)
	else: broadcast.rpc_id(1, method, arguments, CorePath, peer_id)
	return function


#region Broadcaster & Reciever
##TODO-later Monitor safety checks & make sure safety checks work as intended.
##Broadcasts echos.
##Server.broadcast( method, arguments, CorePath, peer_id )
@rpc("any_peer", "reliable") func broadcast(method: String, arg_array: Array, CorePath: Dictionary, peer_id: int = 0) -> void:
	#print("\n"+role+" broadcaster | ",method," | ",arg_array," | CorePath= ",CorePath," | peer_id= ",peer_id)
	var sender_id: int = multiplayer.get_remote_sender_id()##sender_id=0 means server called.
	var host_node: Node = get_corenode(CorePath)
	
	##If Host Node exists
	if host_node == null: push_warning(role+" broadcaster could not find CorePath!= ",CorePath); return
	##If Host Node has method
	if host_node.has_method(method) == false: push_warning(role+" broadcaster could not find method '",method,"' on= ",CorePath); return
	
	#print("\nSender_ID= ",sender_id)
	#print("Host Node Authority= ",host_node.get_multiplayer_authority())
	#print("PeerID= ",peer_id)
	#print("can_sync?= ",can_sync())
	#print("Has peer id?= ",multiplayer.get_peers().has(peer_id)," | Peers= ",multiplayer.get_peers())
	#print("Echoable?= ",echoable_functions.has(host_node) && echoable_functions[host_node].has(method))
	#print("Broadcaster GATE CHECK?= ",sender_id == 0 or sender_id == host_node.get_multiplayer_authority() or (echoable_functions.has(host_node) && echoable_functions[host_node].has(method)))
	
	
	##Safety checks:
	##1. Caller authority needs to have authority over method on calling node.
	##2. Server can echo any function to any peer.
	##if sender = server OR sender authority = host_node authority OR method is echoable
	if sender_id == 0 or sender_id == host_node.get_multiplayer_authority() or (echoable_functions.has(host_node) && echoable_functions[host_node].has(method)):
		##Specify peer.
		if peer_id == 0:##Every peer
			if can_sync(): receiver.rpc(method, arg_array, CorePath)##Broadcast to peers if can_sync
			
			##Call on server
			host_node.call_deferred('callv', method, arg_array)##NOTE: Make sure ALL arguments match! Common Error: Method expected 0 arguments, but called with 0.
		else:##Singular peer
			if peer_id == 1:##Server echo > server > method
				host_node.call_deferred('callv', method, arg_array)##NOTE: Make sure ALL arguments match! Common Error: Method expected 0 arguments, but called with 0.
			else:##Peer > server > someones method
				receiver.rpc_id(peer_id, method, arg_array, CorePath)


##Recieves server broadcast calls.
##Server.receiver( method, arguments, CorePath )
@rpc("authority","reliable") func receiver(method: String, arg_array: Array, CorePath: Dictionary) -> void:
	#print("\n"+role+" receiver= ",method," | ",arg_array," | ",CorePath)
	var host_node: Node = get_corenode(CorePath)
	
	##Host Node exists
	if host_node == null: push_warning(role+" broadcaster could not find CorePath!= ",CorePath); return
	##Host Node has method
	if host_node.has_method(method) == false: push_warning(role+" broadcaster could not find method '",method,"' on= ",CorePath); return
	
	##Call method
	host_node.call_deferred('callv', method, arg_array)##NOTE Make sure ALL arguments match! Common Error: Method expected 0 arguments, but called with 0.
#endregion


#region History Manipulation
##Creates CoreID's for main_scene and every child of main_scene returns properties package.
##Server.package_scene(main_scene: Node) -> properties package
func package_scene(main_scene: Node) -> Dictionary:
	#print("\n"+role+" package_scene | main_scene= ",main_scene)
	##Create main_scene CoreID
	var main_CoreID: int = new_coreid()##New main_scene CoreID
	##print("Monitor= ",main_scene)
	
	var sendback_properties: Dictionary = {'': {}}
	
	##Add main_scene to history.
	history[main_scene] = {}
	
	##If main scene class is synced.
	if update_class_dict.has(get_script_or_class(main_scene)): update_class_scenes[main_scene] = null##Add main scene to update class scenes.
	
	##Handler order:
	##Handle main scene, scene_exiting
	##Handle child scenes, Reparenting + scene_exiting
	
	##Register CoreID & scene events to main_scene.
	register_set(main_scene, main_CoreID)##Set main_scene CoreID
	main_scene.tree_exiting.connect(scene_exiting.bind(main_scene, main_scene))
	
	##Go thru child scenes inside main scene.
	##While there are searchable nodes do.
	var search_nodes: Dictionary = {main_scene: null}
	while search_nodes.size() > 0:
		##print("Current size= ",search_nodes.keys())
		##Search all searchable nodes for scenes.
		for searched_node: Node in search_nodes.keys():##print("\nSearching= ",searched_node)
			for child: Node in searched_node.get_children():##Search thru children
				if child.scene_file_path.length() != 0:##Scene found! Give child a CoreID.
					#print("\nScene= ",child)
					#print("Sync class?= ",get_script_or_class(child))
					
					##New CoreID for child.
					var new_CoreID: int = new_coreid()
					var inner_path: String = '/'+ str(main_scene.get_path_to(child))
					sendback_properties[inner_path] = {'0id': new_CoreID}##Manually add child CoreID
					
					##Add child scene to history.
					history[main_scene][child] = inner_path
					
					
					##If scene class is synced.
					if update_class_dict.has(get_script_or_class(child)): update_class_scenes[child] = null##Add scene to update class scenes.
					
					register_set(child, new_CoreID)##Set CoreID on child scene.
					child.tree_exiting.connect(scene_exiting.bind(child, main_scene))
					
				##If child has more children then add child to be searched.
				if child.get_child_count() > 0: search_nodes[child] = null
			search_nodes.erase(searched_node)##Clear searched children
	return sendback_properties


##ALERT Server side!
##NOTE: The '!inside_scene_tree' error can be ignored since it still sets values (this only affects 'global_transform' values).
##Syncs all child scenes inside given scene as well (altough they do not inherit the same sync_spawn_properties just syncs by the synced class scenes.)
##Server.add( scene: Node, spawn_place: Node, sync_spawn_properties: Dictionary = { "property_name": property_value } )
func add(scene: Node, spawn_place: Node, authority: int = 1, properties: Dictionary = {}) -> void:
	if !multiplayer.is_server(): return##Server side check.
	#print("\n"+role+" add= ",scene," | spawn_place= ",spawn_place," | properties= ",properties)
	if authority != 1: scene.set_multiplayer_authority(authority)##Set multiplayer authority.
	
	
	##Set properties on scene.
	for property_name: String in properties.keys():
		scene.set_deferred(property_name, properties[property_name])
	
	
	##Register scene & child scenes with CoreID's in package_scene & return a CoreID list.
	var coreid_list: Dictionary = package_scene(scene)
	coreid_list[''].merge(properties)##Merge sync properties with CoreID list.
	
	
	##Adds custom spawn scene properties inside spawn_node_properties.
	if properties.size() != 0: spawn_node_properties[scene] = properties.keys()
	
	
	##Add scene to spawn place.
	spawn_place.call_deferred('add_child',scene)
	##print("Added scene ",scene," to spawn_place!= ",spawn_place)
	
	
	##Sync to readied peers if can_sync.
	if can_sync():
		#push_warning("Spawn Add! CoreID= ",node_register[scene]," | authority= ",authority," | peers= ",peers)
		##Only sync to ready peers.
		for peer_id: int in peers.keys():
			if peer_id == 1: continue##Skip server peer_id.
			#push_warning("peer_id= ",peer_id," | is ready?= ",peers[peer_id][&'ready'])
			if peers[peer_id][&'ready']:
				spawn_scene.rpc_id(peer_id, node_register[scene], get_corepath(spawn_place), scene.get_scene_file_path(), authority, coreid_list)
			else:
				#push_warning("Catch back!= ",peer_id," | scene= ",scene," | CoreID= ",node_register[scene]," | history= ",history[scene])
				peers[peer_id][&'catch'][scene] = history[scene]


##NOTE Monitor this function's reparenting logic.
##Scene entered tree after being reparented.
func scene_entered(scene: Node) -> void:
	##print("\n"+role+" scene_entered= ",scene," | ",scene.scene_file_path)
	scene.tree_entered.disconnect(scene_entered)##Disconnect tree_entered signal from scene.
	
	##NOTE: Owned scene does not exist as an actual history entry
	if !history.has(scene): return
	
	##if scene is a reparented scene then
	if history[scene].has('root_owner'):##Check for reparent (OWNED SCENE)
		var original_parent: Node = history[scene]['original_parent']
		var new_parent: Node = scene.get_parent()
		#print("original_parent= ",original_parent,"\nnew_parent= ",new_parent)
		#print("Updated '%s' history with new parent= %s" % [scene.name,new_parent.name] if new_parent != original_parent else "Removed '%s' from history!" % scene.name)
		
		##Update or remove from history.
		if new_parent == original_parent:#Remove reparent log if new parent is the same as original parent.
			history.erase(scene)#Remove logged scene from history
			
			
			original_parents[original_parent].erase(scene)##Erase reparented scene from original_parents[original_parent] entry
			if original_parents[original_parent].size() == 0:##If original_parent is empty then
				original_parents.erase(original_parent)##Erase original_parent entry when empty
				
				if original_parent.get_scene_file_path().length() == 0:##Disconnect original_parent from scene_exiting if it is a scene
					original_parent.tree_exiting.disconnect(scene_exiting)
		else:##Move reparented log down and update new_parent. We move it down cause it could have been reparented to a new main_scene.
			##print("New parent!= ",new_parent)
			var value: Dictionary = history[scene]
			history.erase(scene)
			history[scene] = value
			history[scene]['new_parent'] = new_parent
	else:##If scene is a spawned scene then move to top by removing and adding it back into history again. (OWNER SCENE)
		var values: Dictionary = history[scene]
		history.erase(scene)
		history[scene] = values

##Scene is exiting tree, or it might be getting reparented.
##scene is exiting tree.
##root_owner is scene's root owner.
func scene_exiting(scene: Node, root_owner: Node) -> void:
	#print("\n"+role+" scene_exiting= ",scene," | CoreID= ",node_register.get(scene),
	#" ",scene.is_queued_for_deletion(),
	#"<|>",root_owner.is_queued_for_deletion(),
	#" | root_owner= ",root_owner,
	#" | deleting?= ",is_deleting(scene))
	#" | scene == root_owner?= ",scene == root_owner)
	if scene.is_queued_for_deletion(): clear_data(scene, root_owner)
	elif root_owner.is_queued_for_deletion(): return
	else:
		##Is deleting? then clear data on scene. (is_deleting is slow ish so we only do it here after checking the two most common exiting sources)
		if is_deleting(scene):
			clear_data(scene, root_owner)##Deleting owner scene
			return##Stop
		
		##Return client side. (Client does not mess with history)
		if !multiplayer.is_server(): return
		
		
		##Hook up scene tree entered signal
		scene.tree_entered.connect(scene_entered.bind(scene))
		##Reparenting owned scene.
		if scene != root_owner:
			##Make a reparent entry in history if an entry does not already exist.
			if !history.has(scene):
				##Get & save original parent for future reference.
				var original_parent: Node = scene.get_parent()
				
				##Create reparent entry in History.
				history[scene] = {'root_owner':root_owner, 'original_parent': original_parent, 'new_parent': null}
				
				##Keep track of reparented owned scened from their original parents to make them the owned scenes stand alone when their original parents get deleted. FFR
				if original_parents.has(original_parent):#Add to existing original parent entry.
					original_parents[original_parent].append(scene)
				else:##Make new original parent entry.
					original_parents[original_parent] = [scene]
					
					##Important: Make sure to disconnect original parent scene.
					##Disconnect original parent scene if it no longer has any reparented scenes.
					
					##Hook up original parent with tree_exiting signal if it is a scene so that we know when to make it's owned scenes stand alone.
					if original_parent.get_scene_file_path().length() == 0:
						original_parent.tree_exiting.connect(scene_exiting.bind(original_parent, root_owner))

##Clears data from deleting scene, server & client side.
func clear_data(node: Node, root_owner: Node) -> void:
	#print("\n"+role+" clear_data= ",node," | ",root_owner," | node == root_owner?= ",node == root_owner," | owner exiting?= ",root_owner.is_queued_for_deletion())
	if !is_alive: return##Not alive so this does not matter.
	
	##Server side
	if multiplayer.is_server():
		##Sync deleted node with peers.
		if can_sync():
			if node_register.has(node):##Make sure node is a CoreID.
				free_scene.rpc(get_corepath(node))
		
		
		##Make child scenes stand alone for that are inside exiting original parents.
		##If an original parent is being deleted with links to reparented owned scenes then we have to make the reparented owned scenes stand alone.
		if original_parents.has(node):#An original parent is exiting.
			#Get inner path of node to find child scenes under this inner path.
			#print("node is an original parent!= ",original_parents[node])
			
			##Make a stand_alone_scene key, we use a dictionary cause we could end up adding the same key more than once.
			stand_alone_scenes[node] = {}
			
			##Loop over all reparented scenes for this original_parent.
			for reparented_scene: Node in original_parents[node]:
				#print("Make owned scenes under this reparented scene stand alone. reparented_scene= ",reparented_scene)
				#print("role?= ",role)
				#print("history= ",history)
				#print("node= ",node," | root_owner= ",root_owner," | reparented_scene= ",reparented_scene)
				var reparented_scene_inner_path: String = history[root_owner][reparented_scene]#substr(root_owner.get_path(), reparented_scene.get_path())
				#print("reparented_scene_inner_path= ",reparented_scene_inner_path)
				
				
				#Find owned child scenes under the reparented_scene_inner_path
				for owned_scene in history[root_owner].keys():#print("owned_scene= ",owned_scene)
					if owned_scene is String: continue#Skip deleted scenes
					
					var inner_path: String = history[root_owner][owned_scene]
					if inner_path.begins_with(reparented_scene_inner_path):
						#print(inner_path," begins with!= ",reparented_scene_inner_path)
						
						##Make owned_scene stand alone in scene_exited. FFR
						stand_alone_scenes[node][owned_scene] = null
						
						##Switch owned_scene with inner path.
						history[root_owner].erase(owned_scene)#Remove owned scene that is becoming stand alone
						history[root_owner][inner_path] = null#Replace with null value
		
		
		##Server side switch owned scene with inner path in history.
		if node != root_owner && node.get_scene_file_path().length() != 0:
			var inner_path: String = history[root_owner][node]
			history[root_owner].erase(node)#Remove deleted node
			history[root_owner][inner_path] = null#Replace with null value
	
	
	##Clean all instances of this node.
	update_class_scenes.erase(node)
	spawn_node_properties.erase(node)
	history.erase(node)
	
	if node_register.has(node):
		update_node_properties.erase(node_register[node])
		core_register.erase(node_register[node])##Remove CoreID using CoreNode.
	node_register.erase(node)##Remove CoreNode using CoreID
#endregion


#region Validation & Sync Order
##This validates the connecting peer. Only checks for matching server versions.
@rpc("any_peer","reliable")
func validate(peer_version: StringName):
	var peer_id: int = multiplayer.get_remote_sender_id()
	##print("\n"+role+" validating peer_id= ",peer_id,"\n")
	
	##If peer & server versions do not match then kick.
	if peer_version != version:
		kick_peer(peer_id, 'version missmatch')
		return
	
	##Was further peer validating added?
	if validating.get_connections().size() == 0:
		send_sync_order(peer_id)##No further validation has been added, sync peer now.
	else: validating.emit(peer_id)##Further validation was added. Sync peer if they clear this validation.


##In special cases where a scene is added without a peer being ready then it gets added to that peers catch up list and gets added too.
##Sends sync information to newly connected peer that orders everything to work.
func send_sync_order(peer_id: int, catch_up: Dictionary = history) -> void:
	#print("\nsend sync order to peer_id= ", peer_id," | catch up= ",catch_up)
	#push_warning("\nSend sync order peer_id!= ", peer_id," | CoreID's= ",core_register)
	
	##Remove peer timeout timer.
	if peers[peer_id].has('timeout_timer'):
		if is_instance_valid(peers[peer_id]['timeout_timer']):
			peers[peer_id]['timeout_timer'].queue_free()
	
	##Sync class spawn scenes first
	##Sync spawn nodes after
	##Remove each synced spawn node from sync_spawn_list.
	var sync_spawn_list: Dictionary[Node,PackedStringArray] = spawn_node_properties.duplicate()
	
	
	##For all entries in catch_up
	for scene: Node in catch_up.keys():
		##print("\nscene= ",scene)
		##print("catch_up= ",catch_up[scene])
		var sync_order_properties: Dictionary = {}##{'inner path': {'property_name': property, ...}, ...}
		if catch_up[scene].has('root_owner'):##Found Reparented scene
			#print("\nReparented!= ",scene)
			var root_owner: Node = catch_up[scene]['root_owner']
			var original_CorePath = get_closest_path(root_owner)
			var new_CorePath: Dictionary = get_corepath(catch_up[scene]['new_parent'])
			
			if original_CorePath is Node:##Get CoreNode's CoreID
				original_CorePath = node_register.get(original_CorePath)
			
			reparent_scene.rpc_id(peer_id, {true:original_CorePath,false:catch_up[root_owner][scene]}, new_CorePath)
		else:##Found Spawned scene
			#push_warning("\nSpawned!= ",scene," | inside_tree?= ",scene.is_inside_tree())
			if !scene.is_inside_tree(): await scene.tree_entered#push_error("Awaiting scene to enter tree!= ",scene," | CoreID= ",node_register[scene])
			
			
			#print("has spawn_node_properties?= ",spawn_node_properties.has(scene))
			sync_order_properties[''] = {}##Manually add owner scene self as inner path with ''
			
			##Get class spawn properties.
			if spawn_class_dict.has(get_script_or_class(scene)):
				for property_name: String in spawn_class_dict[get_script_or_class(scene)]:
					sync_order_properties[''][property_name] = scene.get(property_name)
			
			##Get custom spawn properties.
			if spawn_node_properties.has(scene):
				for property_name: String in spawn_node_properties[scene]:
					sync_order_properties[''][property_name] = scene.get(property_name)
				sync_spawn_list.erase(scene)##Remove from sync spawn list.
			
			
			##Loop over child scenes inside spawned scene.
			for key in catch_up[scene].keys():#print("\nkey= ",key," | ",catch_up[scene][key])
				if key is String:##key is an inner path means its a deleted scene.
					sync_order_properties[key] = null
				else:##key == owned scene [existing scene]
					var inner_path: String = catch_up[scene][key]
					
					##Sync owned scene's CoreID
					sync_order_properties[inner_path] = {'0id': node_register[key]}
					
					##Get class spawn properties.
					if spawn_class_dict.has(get_script_or_class(key)):
						for property_name: String in spawn_class_dict[get_script_or_class(key)]:
							sync_order_properties[inner_path][property_name] = key.get(property_name)
					
					##Get custom spawn properties.
					if spawn_node_properties.has(key):
						for property_name: String in spawn_node_properties[key]:
							sync_order_properties[inner_path][property_name] = key.get(property_name)
						sync_spawn_list.erase(key)##Remove from sync spawn list.
			
			##NOTICE
			##print("\nServer Spawn Scene= ",scene)
			##print("Spawn Place= ",scene.get_parent())
			##print("Spawn Path= ",get_corepath_from_node(scene.get_parent()))
			##print("CoreID= ",node_register[scene])
			##print("Properties= ",sync_order_properties)
			spawn_scene.rpc_id(peer_id, node_register[scene], get_corepath(scene.get_parent()), scene.get_scene_file_path(), scene.get_multiplayer_authority(), sync_order_properties)
	
	
	#print("spawn_node_properties= ",spawn_node_properties)
	#print("sync_spawn_list= ",sync_spawn_list)
	##Sync custom node spawn properties.
	var spawn_node_properties_packet: Dictionary = {}
	for node: Node in sync_spawn_list.keys():
		var corepath: Dictionary = get_corepath(node)
		spawn_node_properties_packet[corepath[true]] = {corepath[false]: {}}
		
		for property_name: String in sync_spawn_list[node]:
			spawn_node_properties_packet[corepath[true]][corepath[false]][property_name] = node.get(property_name)
	
	#print("spawn_node_properties_packet= ",spawn_node_properties_packet)
	if spawn_node_properties_packet.size() >0: sync_properties_TCP.rpc_id(peer_id, spawn_node_properties_packet)
	
	
	##NOTE Without waiting weird behaviour happens for unknown reasons (might be packet related desync).
	await get_tree().physics_frame
	#push_warning(peer_id," has catch?= ",peers[peer_id][&'catch'])
	if peers[peer_id][&'catch'].size() >0:
		var temp_catch_up: Dictionary = peers[peer_id][&'catch'].duplicate()
		peers[peer_id][&'catch'].clear()##Duplicated for safety to prevent possible recursion in called function.
		send_sync_order(peer_id, temp_catch_up)
	else:
		peers[peer_id][&'ready'] = true
		ready_peer.emit(peer_id)##Peer is now ready!
#endregion


#region Scene Manipulation
##ALERT Transform related spawn properties should be 'set_deferred' instead of 'set'!
##This spawns dynamic scenes to sync with clients.
##Spawn scene_file_path with CoreID at CorePath with authority and synced properties. If a scene property is null then delete that scene. 
##Server.spawn_scene(spawn path, spawn_scene_file_path, authority)
##Using sync_properties_UDP here I can set all child scene CoreID's
@rpc("authority","reliable")
func spawn_scene(CoreID: int, spawn_CorePath: Dictionary, spawn_scene_file_path: String, authority: int, spawn_properties: Dictionary) -> void:
	##Ignore duplicate scenes! (might be caught by catch up)
	if core_register.has(CoreID): push_warning("CoreID= ",CoreID," already exists! ignoring to spawn_scene!"); return
	
	#push_warning("\n",role," ",multiplayer.get_unique_id()," spawn_scene!",
	#"\nCoreID= ",CoreID,
	#"\nspawn_CorePath= ",spawn_CorePath,
	#"\nspawn_scene_file_path= ",spawn_scene_file_path,
	#"\nauthority= ",authority,
	#"\nsync_spawn_properties= ",{CoreID: spawn_properties})
	
	
	##Node to spawn scene on.
	var spawn_place: Node = get_corenode(spawn_CorePath)
	#print("spawn_place= ",spawn_place)
	
	
	var loaded_scene: Resource = ResourceLoader.load(spawn_scene_file_path)##Load scene
	if loaded_scene == null: push_warning("\n"+role+" spawn_scene invalid scene_file_path!"); return
	
	
	##Handle main scene and its child scenes.
	var main_scene: Node = loaded_scene.instantiate()#Instantiate main scene
	main_scene.set_multiplayer_authority(authority)#Set authority
	
	
	##Sync class main_scene.
	if update_class_dict.has(get_script_or_class(main_scene)): update_class_scenes[main_scene] = null
	
	
	##Gather up nodes with properties to sync them with in one go.
	var node_properties: Dictionary = {}
	
	##Extract child scenes from main_scene to sync their synced properties and delete child scenes that have null as their synced property.
	for inner_path: String in spawn_properties.keys():
		##If properties is null that means this child scene was deleted, so delete it.
		if spawn_properties[inner_path] == null:
			var deleted_scene: Node = main_scene.get_node_or_null(inner_path.right(-1))##.right(-1) removes the / in inner_path
			if is_instance_valid(deleted_scene): deleted_scene.queue_free()##Delete child scene.
			continue
		
		if inner_path == '':##Assign main_scene
			node_properties[main_scene] = spawn_properties[inner_path]
		else:
			var node: Node = main_scene.get_node_or_null(inner_path.right(-1))##.right(-1) removes the / in inner_path
			node_properties[node] = spawn_properties[inner_path]
	#print("\nnode_properties= ",node_properties)
	
	##Sync properties in child scenes
	for node: Node in node_properties.keys():
		if node != null:#print("\n",node)
			for property: String in node_properties[node].keys():##Search thru synced properties & set them.
				if property == '0id': register_set(node, node_properties[node][property]); continue##Set CoreID
				if property == 'transform' or property == 'position':##ALERT Transform related spawn properties should be 'set_deferred' instead of 'set'!
					#print(node," set_deferred ",property," = ",node_properties[node][property])
					node.set_deferred(property, node_properties[node][property])
				else:
					#print(node," set ",property," = ",node_properties[node][property])
					node.set(property, node_properties[node][property])
		else: push_warning("\n"+role+" spawn_scene sync spawn node is null!")
	
	
	##Register main_scene with CoreID
	register_set(main_scene, CoreID)
	main_scene.tree_exiting.connect(scene_exiting.bind(main_scene, main_scene))
	
	##NOTE This is like the client side version of 'package_scene'.
	##While there are searchable nodes.
	var search_nodes: Dictionary = {main_scene: null}
	while search_nodes.size() > 0:
		##print("Current size= ",search_nodes.keys())
		for searched_node: Node in search_nodes.keys():#print("\nSearching= ",searched_node)
			##Search thru children
			for child: Node in searched_node.get_children():
				if child.scene_file_path.length() != 0:##Scene found!
					
					##Sync class scene.
					if update_class_dict.has(get_script_or_class(child)): update_class_scenes[child] = null
					
					child.tree_exiting.connect(scene_exiting.bind(child, main_scene))
				
				##Child has more children then add child to be searched.
				if child.get_child_count() > 0: search_nodes[child] = null
			search_nodes.erase(searched_node)##Clear searched children
	
	#push_warning("Spawned= ",spawn_CorePath," | ",spawn_scene_file_path)
	#if spawn_place == null:
		#push_warning("spawn_place is null!= ",spawn_CorePath," | ",spawn_scene_file_path)
	##Add main_scene to spawn_place.
	spawn_place.add_child(main_scene)##ALERT Do not call_deferred here...



##Removes scenes/nodes across the network as reliably as possible.
##Server.free_scene( CorePath )
@rpc("reliable") func free_scene(CorePath: Dictionary) -> void:
	#print("\n"+role+" free_scene CorePath= ",CorePath," | host_node= ",get_corenode(CorePath))
	var host_node: Node = get_corenode(CorePath)
	if is_instance_valid(host_node): host_node.queue_free()
	else: push_warning(role+" could not remove invalid or missing node from CorePath!= ",CorePath)


##Reparents child scenes inside a spawned scene to their new parent.
##Server.reparent_scene( CorePath, CorePath, bool )
@rpc("reliable") func reparent_scene(reparented_CorePath: Dictionary, new_CorePath: Dictionary, keep_global_transform: bool = true) -> void:
	##print(role+" reparented!= ",reparented_CorePath," to ",new_CorePath," | ",keep_global_transform)
	var reparenting_scene: Node = get_corenode(reparented_CorePath)
	var parent_scene: Node = get_corenode(new_CorePath)
	if reparenting_scene and parent_scene:
		reparenting_scene.reparent(parent_scene, keep_global_transform)
	else: push_warning(role+" reparent_scene with NULL! reparenting_scene= %s + %s | parent_scene= %s + %s" % [reparenting_scene, reparented_CorePath, parent_scene, new_CorePath])
#endregion


##Server= start_multiplayer(true, server size, port, timeout_time)
##Client= start_multiplayer(false, internet protocol address, port, timeout_time)
##Server.start_multiplayer(is_server, address_or_size, port, timeout_time ) -> Error Enum, 'OK' == success
func start_multiplayer(is_server: bool, address_or_size: String, port: int = 1090, timeout_time: float = timeout) -> Error:
	##print("Started multiplayer! is_server= ",is_server," | address_or_size= ",address_or_size," | port= ",port)
	timeout = timeout_time
	var error: Error = Error.FAILED
	if is_server:##Create server
		error = multiplayer_protocol.create_server(port, clampi(int(address_or_size), 1, 4095))
		multiplayer.multiplayer_peer = multiplayer_protocol
		if error == OK: is_alive = true
		else: push_warning("Failed to create server! Error= "+error_string(error)," | server size= ",address_or_size," | port= ",port)
	else:##Create client
		error = multiplayer_protocol.create_client(address_or_size, port)
		multiplayer.multiplayer_peer = multiplayer_protocol
		if error == OK:
			##Client timeout after trying to find a server.
			var server_timeout_timer: Timer = count_down(timeout)
			server_timeout_timer.timeout.connect(handle_rejection.bind('timeout'))
			peers[1]['timeout_timer'] = server_timeout_timer
		else: push_warning("Failed to create client! Error= "+error_string(error)," | address= ",address_or_size," | port= ",port)
	return error


##Handles rejection when disconnected from server or when cancelling to join a server.
func handle_rejection(rejection_reason: String = '') -> void:
	#if !is_alive: return##Must be alive to handle rejection!
	#print("Handle rejection! reason= ",rejection_reason," | timeout_time= ",timeout," | is_alive?= ",is_alive)
	
	##Still has timeout_timer?
	##print("has timeout timer?= ",peers[1].get("timeout_timer"))
	if peers[1].has('timeout_timer'):
		if is_instance_valid(peers[1]['timeout_timer']):
			peers[1]['timeout_timer'].queue_free()
	
	
	##Reset multiplayer & all server sync values like history, CoreID's and so on..
	is_alive = false
	multiplayer_protocol.close()
	
	##Reset peers
	peers = {1: {&'MTU': MTU, &'ready': true}}
	
	##Reset registers
	core_register.clear()
	node_register.clear()
	
	
	##Update & spawn clearing
	update_class_scenes.clear()
	update_node_properties.clear()
	spawn_node_properties.clear()
	
	isolated_classes.clear()
	isolated_properties.clear()
	
	
	##Continue reject signal
	rejected.emit(rejection_reason)


##Kick/Boot peer
##Server.kick_peer(peer_id: int, kick_reason: Error, kick_string: String, forced: bool)
func kick_peer(peer_id: int, kick_reason: String = '', forced: bool = false) -> void:
	##print("Kicked peer!= ",peer_id," | reason= ",kick_reason," | forced?= ",forced)
	if peer_id == 1: push_warning("Can not kick server!"); return
	
	if forced: multiplayer.multiplayer_peer.disconnect_peer(peer_id)
	else: echo(handle_rejection.bind(kick_reason), peer_id); multiplayer_protocol.get_peer(peer_id).peer_disconnect_later()


#region Peer connected/disconnected to/from server
##Gets called once for every peer who joins the same server
func peer_connected(peer_id: int) -> void:
	##push_warning("peer_connected= ",peer_id," is_server?= ",multiplayer.is_server())
	##Create new data container for connected peer.
	peers[peer_id] = {&'catch': {}, &'MTU': MTU, &'ready': false}
	
	if !multiplayer.is_server(): return##Return client side
	
	##Timeout peer if server does not receive the peers validate rpc within the timeout time.
	var peer_timeout_timer: Timer = count_down(clampf(timeout, 1.0, 30.0))
	peer_timeout_timer.timeout.connect(kick_peer.bind(peer_id,'timeout'))
	peers[peer_id]['timeout_timer'] = peer_timeout_timer


func peer_disconnected(peer_id: int) -> void:
	##push_warning("peer_disconnected= ",peer_id," is_server?= ",multiplayer.is_server())
	if !multiplayer.is_server(): return##Return client side
	
	await wait(.1)##Let other functions have time to clean up peer data first.
	peers.erase(peer_id)
#endregion

#region Connected/Disconnected to/from server
func server_connected() -> void:
	##print("Connected to server! ID= ",multiplayer.get_unique_id())
	is_alive = true
	peers[1]['timeout_timer'].queue_free()##Remove client side timeout timer
	validate.rpc_id(1, version)##Validate with server.
	peers[multiplayer.get_unique_id()] = {&'MTU': MTU}##Create new data container for client.

func server_disconnected() -> void:
	##print("Disconnected from server! is_alive?= ",is_alive)
	if is_alive: handle_rejection('disconnected')
#endregion


#region Getters
##NOTE Raw CorePath data cannot be used by synced classes/synced properties.
##Get node from CorePath.
##Server.get_corenode( {true: CoreID/NodePath, false: "/inner_path"} ) -> Node
func get_corenode(CorePath: Dictionary) -> Node:
	#print("get_node_from_corepath= ",CorePath)
	if CorePath.size() == 0: push_warning(role," get_corenode CorePath is empty!= ",CorePath); return
	var CoreNode: Node = null
	var CoreID = CorePath[true]##CoreID or NodePath
	if CoreID is int:##CoreID
		if is_instance_valid(core_register.get(CoreID)):
			CoreNode = core_register.get(CoreID)
			if CorePath[false].length() != 0:##Continue to get inner node
				var full_path: String = str(CoreNode.get_path())+ CorePath[false]
				#print("full_path= ",full_path)
				CoreNode = get_node_or_null(full_path)
	elif CoreID is NodePath: CoreNode = get_node_or_null(CoreID)
	if !is_instance_valid(CoreNode): push_warning("\n"+role+" get_corenode did not find CoreNode from CorePath= ",CorePath)
	return CoreNode


##NOTE Raw CorePath data cannot be used by synced classes/synced properties.
##Get CorePath from node.
##Server.get_corepath( Node ) -> {true: CoreID/NodePath, false: "/inner_path"}
func get_corepath(node: Node) -> Dictionary:
	var CorePath: Dictionary = {}
	var closest_path = get_closest_path(node)
	##print("closest_path= ",closest_path)
	if closest_path is Node:
		CorePath[true] = node_register[closest_path]##CoreID
		CorePath[false] = substr(node.get_path(), closest_path.get_path())##Inner_path
	elif closest_path is NodePath: CorePath[true] = node.get_path()
	return CorePath

##TODO-NOTE Convert to CoreID finding only?
##NOTE Monitor for efficency & edge cases.
##Gets the most reliable path to any node.
##Server.get_closest_path( Node ) -> CoreID Scene / NodePath
func get_closest_path(node: Node) -> Variant:
	#print("\n"+role+" get_closest_path= ",node)
	##This is our "probe" value where we check for CoreID or NodePath in the hierarchy
	var probe: Node = node
	var CorePath = null
	
	##While no CorePath, try finding it.
	while CorePath == null:
		if probe.scene_file_path.length() != 0:##Probe is a scene
			##print("Scene= ",probe)
			##print("Has CoreID?= ",node_register.has(probe))
			
			##If Probe has CoreID
			if node_register.has(probe):##Has CoreID
				CorePath = probe
			else:##No CoreID
				##Check for parent
				if probe.get_parent():##Probe parent
					probe = probe.get_parent()
				else:##Use node path if no parent found.
					CorePath = node.get_path()
		else:##Probe was not a scene then get its owner
			##print("Not scene= ",probe)
			if probe.get_parent():
				probe = probe.get_parent()
			else:
				CorePath = node.get_path()
	return CorePath


##Returns the root owner of node.
func get_root_owner(node: Node) -> Node:
	while node.get_owner() != null: node = node.get_owner()
	return node


##Returns a usable class for server.
func get_script_or_class(node: Node) -> Variant:
	var script: Script = node.get_script()
	@warning_ignore("incompatible_ternary")
	return script if script != null else node.get_class()
#endregion


##Register Node with a CoreID.
func register_set(node: Node, coreid: int) -> void:
	##print("\n"+role+" register_set= ",node," | ",coreid)
	##Set both registers.
	core_register[coreid] = node
	node_register[node] = coreid


##ALERT High desync potential with new peers that join.
##NOTE: Cooldown example: get_tree().create_timer(cool_down_time).timeout.connect(func(): cool_down = false)
##Waits time in seconds or a single frame by default.
##await Server.wait( wait_time_in_seconds: float ) 
func wait(time: float = get_process_delta_time(), process_always: bool = true, process_in_physics: bool = false, ignore_time_scale: bool = false) -> void:
	await get_tree().create_timer(time, process_always, process_in_physics, ignore_time_scale).timeout

##NOTE: Cooldown example: get_tree().create_timer(cool_down_time).timeout.connect(func(): cool_down = false)
##Counts down time in seconds or a single frame by default.
##Server.count_down( wait_time_in_seconds: float ) -> Timer
func count_down(time: float = get_process_delta_time()) -> Timer:
	var new_timer: Timer = Timer.new()
	new_timer.autostart = true
	new_timer.one_shot = true##Do not repeat.
	new_timer.wait_time = time##Set wait time
	new_timer.timeout.connect(new_timer.queue_free)##Delete new_timer after timeout.
	call_deferred('add_child', new_timer)
	return new_timer


##Converts a human readable bool string to bool, returns false by default.
func string_to_bool(bool_stirng: String) -> bool:
	match bool_stirng:
		'true': return true
		'on': return true
		'1': return true
		'0': return false
		'off': return false
		'false': return false
		_: return false


##Finds a new CoreID.
##Server.new_coreid() -> CoreID
func new_coreid() -> int:
	var CoreID: int = core_register.size()
	while true:
		if core_register.has(CoreID):##CoreID is clamied
			CoreID += 1##increase by 1
		else:##CoreID is unclaimed
			return CoreID##Return CoreID
	return CoreID


##Check if given scene is being deleted.
##Server.is_deleting( scene ) -> bool
func is_deleting(scene: Node) -> bool:
	##print("is deleting?= ",scene)
	var _root: Node = get_tree().get_root()
	while scene != _root:##Move up in tree and check for deleting scenes until root is reached.
		if scene.is_queued_for_deletion(): return true
		scene = scene.get_parent()
	return false

##Returns true if is server & has peers.
func can_sync() -> bool: return (is_alive && multiplayer.is_server() && multiplayer.get_peers().size() > 0)

##String subtraction, removes 'negative' amount of characters from the left of 'target'. 
##Server.substr("/root/player/rifle", "/root/player") -> "/rifle"
func substr(target: String, negative: String) -> String: return target.right(-negative.length())
