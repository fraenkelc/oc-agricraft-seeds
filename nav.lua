local nav = {}

local component = require("component")
local c_nav = component.proxy(component.list("navigation")())
local c_rob = component.proxy(component.list("robot")())

local sides = require("sides")

function nav.turnTo(facing)
  while (c_nav.getFacing() ~= facing) do
    c_rob.turn(true) 
  end
end


function nav.moveRel(directions)
  -- move in x axis
  local targetDir = -1
  if ( directions[1] ~= 0) then
    local toMove = math.abs(directions[1])
    if (directions[1]<toMove) then 
      targetDir = sides.west
    else
      targetDir = sides.east
    end
    nav.turnTo(targetDir)
    while (toMove > 0) do
      c_rob.move(sides.front)
      toMove = toMove -1
    end
  end
  -- move in z axis
  if ( directions[3] ~= 0) then
    local toMove = math.abs(directions[3])
    if (directions[3]<toMove) then 
      targetDir = sides.north
    else
      targetDir = sides.south
    end
    nav.turnTo(targetDir)
    while (toMove > 0) do
      c_rob.move(sides.front)
      toMove = toMove -1
    end
  end
  
end

return nav