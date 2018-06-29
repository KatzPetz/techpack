--[[

	sl_controller
	=============

	Copyright (C) 2018 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information

	controller.lua:

]]--

local sHELP = [[SaferLua Controller

 This controller is used to control and monitor 
 Tubelib/TechPack machines.
 This controller can be programmed in Lua.
 
 See on GitHub for more help: goo.gl/Et8D6n

 The controller only runs, if a battery is 
 placed nearby.
 
]]

local Cache = {}

local tCommands = {}
local tFunctions = {" Overview", " Data structures"}
local tHelpTexts = {[" Overview"] = sHELP, [" Data structures"] = safer_lua.DataStructHelp}
local sFunctionList = ""
local tFunctionIndex = {}

minetest.after(2, function() 
	sFunctionList = table.concat(tFunctions, ",") 
	for idx,key in ipairs(tFunctions) do
		tFunctionIndex[key] = idx
	end
end)

local function output(pos, text)
	local meta = minetest.get_meta(pos)
	text = meta:get_string("output") .. "\n" .. (text or "")
	text = text:sub(-500,-1)
	meta:set_string("output", text)
end

--
-- API functions for function/action registrations
--
function sl_controller.register_function(key, attr)
	tCommands[key] = attr.cmnd
	table.insert(tFunctions, " $"..key)
	tHelpTexts[" $"..key] = attr.help
end

function sl_controller.register_action(key, attr)
	tCommands[key] = attr.cmnd
	table.insert(tFunctions, " $"..key)
	tHelpTexts[" $"..key] = attr.help
end

local function merge(dest, keys, values)
  for idx,key in ipairs(keys) do
    dest.env[key] = values[idx]
  end
  return dest
end

sl_controller.register_action("print", {
	cmnd = function(self, text1, text2, text3)
		local pos = self.meta.pos
		text1 = tostring(text1 or "")
		text2 = tostring(text2 or "")
		text3 = tostring(text3 or "")
		output(pos, text1..text2..text3)
	end,
	help = " $print(text,...)\n"..
		" Send a text line to the output window.\n"..
		" The function accepts up to 3 text strings\n"..
		' e.g. $print("Hello ", name, " !")'
})

sl_controller.register_action("loopcycle", {
	cmnd = function(self, cycletime)
		cycletime = math.floor(tonumber(cycletime) or 0)
		local meta = minetest.get_meta(self.meta.pos)
		meta:set_int("cycletime", cycletime)
		meta:set_int("cyclecount", 0)
	end,
	help = "$loopcycle(seconds)\n"..
		" This function allows to change the\n"..
		" call frequency of the loop() function.\n"..
		" value is in seconds, 0 = disable\n"..
		' e.g. $loopcycle(10)'
})

sl_controller.register_action("events", {
	cmnd = function(self, event)
		self.events = event or false
	end,
	help = "$events(true/false)\n"..
		" Enable/disable event handling.\n"..
		' e.g. $events(true) -- enable events'
})


local function formspec0(meta)
	local running = meta:get_int("state") == tubelib.RUNNING
	local cmnd = running and "stop;Stop" or "start;Start" 
	local init = meta:get_string("init")
	init = minetest.formspec_escape(init)
	return "size[4,3]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"label[0,0;No Battery?]"..
	"button[1,2;1.8,1;start;Start]"
end

local function formspec1(meta)
	local running = meta:get_int("state") == tubelib.RUNNING
	local cmnd = running and "stop;Stop" or "start;Start" 
	local init = meta:get_string("init")
	init = minetest.formspec_escape(init)
	return "size[10,8]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"tabheader[0,0;tab;init,loop,outp,notes,help;1;;true]"..
	"textarea[0.3,0.2;10,8.3;init;function init();"..init.."]"..
	"label[0,7.3;end]"..
	"button_exit[4.4,7.5;1.8,1;cancel;Cancel]"..
	"button[6.3,7.5;1.8,1;save;Save]"..
	"button[8.2,7.5;1.8,1;"..cmnd.."]"
end

local function formspec2(meta)
	local running = meta:get_int("state") == tubelib.RUNNING
	local cmnd = running and "stop;Stop" or "start;Start"
	local loop = meta:get_string("loop")
	loop = minetest.formspec_escape(loop)
	return "size[10,8]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"tabheader[0,0;tab;init,loop,outp,notes,help;2;;true]"..
	"textarea[0.3,0.2;10,8.3;loop;function loop(ticks, elapsed);"..loop.."]"..
	"label[0,7.3;end]"..
	"button_exit[4.4,7.5;1.8,1;cancel;Cancel]"..
	"button[6.3,7.5;1.8,1;save;Save]"..
	"button[8.2,7.5;1.8,1;"..cmnd.."]"
end

local function formspec3(meta)
	local running = meta:get_int("state") == tubelib.RUNNING
	local cmnd = running and "stop;Stop" or "start;Start" 
	local output = meta:get_string("output")
	output = minetest.formspec_escape(output)
	return "size[10,8]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"tabheader[0,0;tab;init,loop,outp,notes,help;3;;true]"..
	"textarea[0.3,0.2;10,8.3;help;Output:;"..output.."]"..
	"button[4.4,7.5;1.8,1;clear;Clear]"..
	"button[6.3,7.5;1.8,1;update;Update]"..
	"button[8.2,7.5;1.8,1;"..cmnd.."]"
end

local function formspec4(meta)
	local notes = meta:get_string("notes")
	notes = minetest.formspec_escape(notes)
	return "size[10,8]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"tabheader[0,0;tab;init,loop,outp,notes,help;4;;true]"..
	"textarea[0.3,0.2;10,8.3;notes;Notepad:;"..notes.."]"..
	"button_exit[6.3,7.5;1.8,1;cancel;Cancel]"..
	"button[8.2,7.5;1.8,1;save;Save]"
end

local function formspec5(items, pos, text)
	text = minetest.formspec_escape(text)
	return "size[10,8]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"tabheader[0,0;tab;init,loop,outp,notes,help;5;;true]"..
	"label[0,-0.2;Functions:]"..
	"dropdown[0.3,0.2;10,8.3;functions;"..items..";"..pos.."]"..
	"textarea[0.3,1.3;10,8;help;Help:;"..text.."]"
end

local function error(pos, err)
	output(pos, err)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	meta:set_string("formspec", formspec3(meta))
	meta:set_string("infotext", "Controller "..number..": error")
	meta:set_int("state", tubelib.STOPPED)
	minetest.get_node_timer(pos):stop()
	return false
end

local function compile(pos, meta, number)
	local init = meta:get_string("init")
	local loop = meta:get_string("loop")
	local owner = meta:get_string("owner")
	local env = table.copy(tCommands)
	env.meta = {pos=pos, owner=owner, number=number, error=error}
	local code = safer_lua.init(pos, init, loop, env, error)
	
	if code then
		Cache[number] = {code=code, inputs={}}
		return true
	end
	return false
end

local function battery(pos)
	local battery_pos = minetest.find_node_near(pos, 1, {"sl_controller:battery"})
	if battery_pos then
		local meta = minetest.get_meta(pos)
		meta:set_string("battery", minetest.pos_to_string(battery_pos))
		return true
	end
	return false
end	

local function start_controller(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	if not battery(pos) then
		meta:set_string("formspec", formspec0(meta))
		return false
	end
	
	meta:set_string("output", "<press update>")
	meta:set_string("formspec", formspec3(meta))
	meta:set_int("cycletime", 1)
	meta:set_int("cyclecount", 0)
	meta:set_int("cpu", 0)
	
	if compile(pos, meta, number) then
		meta:set_int("state", tubelib.RUNNING)
		minetest.get_node_timer(pos):start(1)
		meta:set_string("infotext", "Controller "..number..": running")
		return true
	end
	return false
end

local function stop_controller(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	meta:set_int("state", tubelib.STOPPED)
	minetest.get_node_timer(pos):stop()
	meta:set_string("infotext", "Controller "..number..": stopped")
	meta:set_string("formspec", formspec2(meta))
end

local function no_battery(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	meta:set_int("state", tubelib.STOPPED)
	minetest.get_node_timer(pos):stop()
	meta:set_string("infotext", "Controller "..number..": No battery")
	meta:set_string("formspec", formspec0(meta))
end

local function update_battery(meta, cpu)
	local pos = minetest.string_to_pos(meta:get_string("battery"))
	if pos then
		meta = minetest.get_meta(pos)
		local content = meta:get_int("content") - cpu
		if content <= 0 then
			meta:set_int("content", 0)
			return false
		end
		meta:set_int("content", content)
		return true
	end
end

local function call_loop(pos, meta, elapsed)
	local t = minetest.get_us_time()
	local number = meta:get_string("number")
	if Cache[number] or compile(pos, meta, number) then
		
		local cpu = meta:get_int("cpu") or 0
		local code = Cache[number].code
		local res = safer_lua.run_loop(pos, elapsed, code, error)
		if res then 
			t = minetest.get_us_time() - t
			cpu = math.floor(((cpu * 20) + t) / 21)
			meta:set_int("cpu", cpu)
			meta:set_string("infotext", "Controller "..number..": running ("..cpu.."us)")
			if not update_battery(meta, cpu) then
				no_battery(pos)
				return false
			end
		end
		return res
	end
	return false
end

local function on_timer(pos, elapsed)
	local meta = minetest.get_meta(pos)
	-- considering cycle frequency
	local cycletime = meta:get_int("cycletime") or 1
	local cyclecount = (meta:get_int("cyclecount") or 0) + 1
	if cyclecount < cycletime then
		meta:set_int("cyclecount", cyclecount)
		return true
	end
	meta:set_int("cyclecount", 0)

	return call_loop(pos, meta, elapsed)
end

local function on_receive_fields(pos, formname, fields, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	local meta = minetest.get_meta(pos)
	
	--print(dump(fields))
	if fields.cancel == nil then
		if fields.init then
			meta:set_string("init", fields.init)
			meta:set_string("formspec", formspec1(meta))
		elseif fields.loop then
			meta:set_string("loop", fields.loop)
			meta:set_string("formspec", formspec2(meta))
		elseif fields.notes then
			meta:set_string("notes", fields.notes)
			meta:set_string("formspec", formspec4(meta))
		end	
	end
	
	if fields.update then
		meta:set_string("formspec", formspec3(meta))
	elseif fields.clear then
		meta:set_string("output", "<press update>")
		meta:set_string("formspec", formspec3(meta))
	elseif fields.tab == "1" then
		meta:set_string("formspec", formspec1(meta))
	elseif fields.tab == "2" then
		meta:set_string("formspec", formspec2(meta))
	elseif fields.tab == "3" then
		meta:set_string("formspec", formspec3(meta))
	elseif fields.tab == "4" then
		meta:set_string("formspec", formspec4(meta))
	elseif fields.tab == "5" then
		meta:set_string("formspec", formspec5(sFunctionList, 1, sHELP))
	elseif fields.start == "Start" then
		start_controller(pos)
		minetest.log("action", player:get_player_name() ..
			" starts the sl_controller at ".. minetest.pos_to_string(pos))
	elseif fields.stop == "Stop" then
		stop_controller(pos)
	elseif fields.functions then
		local key = fields.functions
		local text = tHelpTexts[key] or ""
		local pos = tFunctionIndex[key] or 1
		meta:set_string("formspec", formspec5(sFunctionList, pos, text))
	end
end

minetest.register_node("sl_controller:controller", {
	description = "SaferLua Controller",
	inventory_image = "sl_controller_inventory.png",
	wield_image = "sl_controller_inventory.png",
	stack_max = 1,
	tiles = {
		-- up, down, right, left, back, front
		"smartline.png",
		"smartline.png",
		"smartline.png",
		"smartline.png",
		"smartline.png",
		"smartline.png^sl_controller.png",
	},

	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -6/32, -6/32, 14/32,  6/32,  6/32, 16/32},
		},
	},
	
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		local number = tubelib.add_node(pos, "sl_controller:controller")
		meta:set_string("owner", placer:get_player_name())
		meta:set_string("number", number)
		meta:set_int("state", tubelib.STOPPED)
		meta:set_string("init", "-- called only once")
		meta:set_string("loop", "-- called every second")
		meta:set_string("notes", "For your notes / snippets")
		meta:set_string("formspec", formspec1(meta))
		meta:set_string("infotext", "Controller "..number..": stopped")
	end,

	on_receive_fields = on_receive_fields,
	
	on_dig = function(pos, node, puncher, pointed_thing)
		if minetest.is_protected(pos, puncher:get_player_name()) then
			return
		end
		
		minetest.node_dig(pos, node, puncher, pointed_thing)
		tubelib.remove_node(pos)
	end,
	
	on_timer = on_timer,
	
	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = {choppy=1, cracky=1, crumbly=1},
	is_ground_content = false,
	sounds = default.node_sound_stone_defaults(),
})


minetest.register_craft({
	type = "shapeless",
	output = "sl_controller:controller",
	recipe = {"smartline:controller"}
})

-- write inputs from remote nodes
local function set_input(pos, number, input, val)
	if input then 
		if Cache[number] and Cache[number].inputs then
			-- only one event per second
			local t = minetest.get_us_time()
			if not Cache[number].last_event or Cache[number].last_event < t then
				Cache[number].inputs[input] = val
				local meta = minetest.get_meta(pos)
				minetest.after(0.1, call_loop, pos, meta, -1)
				Cache[number].last_event = t + 1000000 -- add one second
			end
		end
	end
end	

-- used by the command "input"
function sl_controller.get_input(number, input)
	if input then 
		if Cache[number] and Cache[number].inputs then
			return Cache[number].inputs[input] or "off"
		end
	end
	return "off"
end	

tubelib.register_node("sl_controller:controller", {}, {
	on_recv_message = function(pos, topic, payload)
		local meta = minetest.get_meta(pos)
		local number = meta:get_string("number")
		
		if topic == "on" then
			set_input(pos, number, payload, topic)
		elseif topic == "off" then
			set_input(pos, number, payload, topic)
		elseif topic == "state" then
			local state = meta:get_int("state")
			return tubelib.statestring(state)
		else
			return "unsupported"
		end
	end,
})		
