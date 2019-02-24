local component = require("component")
local rob = require('robot')
local sides = require("sides")
local event = require('event')
local c_nav = component.proxy(component.list("navigation")())
local c_rob = component.proxy(component.list("robot")())
local c_inv = component.proxy(component.list("inventory_controller")())
local c_geo = component.proxy(component.list("geolyzer")())

local nav = require('nav')
local timerID

local slot_clippers = 1

function restock()
  -- dump stuff into storage
  for i = 5,c_rob.inventorySize() do
    c_rob.select(i)
    if (c_rob.count() > 0) then 
      c_rob.drop(sides.up)
    end
  end
  -- then fill up on crops
  -- find the source slot
  local sourceSlot
  for i = 1, c_inv.getInventorySize(sides.up) do
    local stack = c_inv.getStackInSlot(sides.up, i)
    if (stack and stack.name=="agricraft:crop_sticks") then
      sourceSlot = i
      break
    end
  end
  -- now suck into our inventories
  for i = 2, 4 do
    c_rob.select(i)
    if (c_rob.space() > 0) then
      c_inv.suckFromSlot(sides.up, sourceSlot, c_rob.space())
    end
  end
end

function waitForGrowth()
  nav.moveRel(navPoint('end').position)
  -- move the robot one block back, but still facing the last crop
  nav.turnTo(getFacing(navPoint('start').position))
  c_rob.move(sides.front)
  c_rob.turn(true)
  c_rob.turn(true)
  
  local foundCrop = false
  repeat  
    os.sleep(2)
    c_rob.move(sides.front)
    -- now use the clippers and check if we got an item in the inventory
    c_rob.select(slot_clippers)
    c_inv.equip()  
    c_rob.use(sides.down)
    c_inv.equip()
    c_rob.move(sides.back)
    -- check if we picked up something
    for i=5, c_rob.inventorySize() do
      local stack = c_inv.getStackInInternalSlot(i)
      if (stack ) then
        c_rob.select(i)
        c_rob.drop(sides.up)
        if (stack.name == "agricraft:clipping") then
          foundCrop = true
        end
      end
    end
  until (foundCrop)
  c_rob.move(sides.front)
  
end

function forAllBlocks(target, func) 
  local length
  local width
  local turnDirClockwise = true;
  nav.turnTo(getFacing(target))
  
 
  if (math.abs(target[1]) > math.abs(target[3])) then
    length = math.abs(target[1])
    width = target[3]
  else
    length = math.abs(target[3])
    width = target[1]    
  end
  
  local facing = c_nav.getFacing()
  if (width < 0) then
    width = math.abs(width)
    turnDirClockwise = facing == sides.negx or facing == sides.posz
  else
    turnDirClockwise = facing == sides.posx or facing == sides.negz
  end
  
  
  while (width >= 0) do 
    
    func()
    for i = 1, length do 
      -- now move
      c_rob.move(sides.front)
      func()
    end
    
    -- now turn around the corner
    if(width > 0) then
      c_rob.turn(turnDirClockwise)
      c_rob.move(sides.front)
      c_rob.turn(turnDirClockwise)
      turnDirClockwise = not turnDirClockwise
    end
    width = width - 1
  end
  
end

function setupCrops()
  local target = navPoint('end').position
  forAllBlocks(navPoint('start').position, clearCrops)
  c_rob.select(2)
  equipCrops(true)
  forAllBlocks(navPoint('end').position, placeCrops)
end

function clearCrops()
  local block = c_geo.analyze(sides.down)
  if (block.name=="agricraft:crop") then
    c_rob.swing(sides.down)
  end
end

function placeCrops()
  local block = c_geo.analyze(sides.down)
  if (block.name=="minecraft:air") then
    equipCrops()
    c_rob.use(sides.down)
    c_rob.use(sides.down)
  end
end

local equipUseCnt = 0;
function equipCrops(force)
  force = force or false
  if (force) then equipUseCnt = -1 end
  equipUseCnt = equipUseCnt +1
  if ((equipUseCnt % 10) == 0) then
    print("Trying to equip more crops")
    -- build a stack of crops at the current slot
    local slotNo = c_rob.select()
    local missing = c_rob.space()
    for i = slotNo+1, c_rob.inventorySize() do
      c_rob.select(i)
      if (c_rob.compareTo(slotNo)) then
        local toMove = math.min(missing, c_rob.count() -1)
        if (toMove > 0) then
          c_rob.transferTo(slotNo, toMove)
          missing = missing - toMove
          end
        if (missing <= 0) then
          break
        end
      end
    end
    
    -- equip them
    c_rob.select(slotNo);
    c_inv.equip()
  end
end

function navPoint(label, range)
  range = range or 30
  local points = c_nav.findWaypoints(range)
  for i, v in ipairs(points) do
    if (label == v.label) then
      return v
    end
  end
  return nil
end

function getFacing(pos) 
  local targetDir = -1
  -- find the longer axis
  if (math.abs(pos[1]) > math.abs(pos[3])) then
    if (pos[1] > 0) then 
      targetDir=sides.east
    else
      targetDir=sides.west
    end
  else
    if (pos[3] > 0) then 
      targetDir=sides.south
    else
      targetDir=sides.north
    end
  end
  return targetDir
end

function returnToStart()
  io.write("Returning to start")
  nav.moveRel(navPoint('start').position)
  
  nav.turnTo(getFacing(navPoint('end').position))
end


function main()
  while(true) do
    waitForGrowth()
    setupCrops()
    restock()
  end
end

main()
