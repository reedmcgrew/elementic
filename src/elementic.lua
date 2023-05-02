-- constants
local empty_tile = 0
local dirt = 11
local dirt_slope_right = 13
local dirt_slope_left = 12
local magma = 51
local magma_slope_left = 9
local magma_slope_right = 10
local magma_layer_entrance = 52
local grass = 43
local grass_slope_right = 6
local grass_slope_left = 7
local stone = 8
local stone_slope_right = 40
local stone_slope_left = 41

-- map dimensions
local map_width = 128
local map_height = 16

local character = {
    x = 1*8, -- initial x position
    y = 7*8, -- initial y position
    speed = 1, -- movement speed
    sprite = 3, -- sprite index
    vy = 0, -- vertical velocity
    gravity = 0.2, -- gravity strength
    jump_strength = -2.5 -- jump strength (negative value to jump upwards)
}

local boss_start_position_x = 7*8
local boss_start_position_y = 9*8
local boss = {
    x = boss_start_position_x, -- initial x position
    y = boss_start_position_y, -- initial y position
    sprite = 60, -- sprite index for the normal face
    frowny_sprite = 17, -- sprite index for the frowny face
    health = 3,
    invulnerable = false,
    defeated = false,
    state = "holding_pattern",
    holding_pattern_width = 8*8,
    earth_shake_timer = 0,
    vulnerability_timer = 0,
    invulnerability_timer = 0,
    direction = 1, -- initial direction (1 for right, -1 for left)
    speed = 0.5 -- movement speed
}

function is_solid_tile(tile)
    return tile == stone or
            tile == magma or
            tile == grass or
            tile == dirt
end

function is_right_slope_tile(tile)
    return tile == stone_slope_right or
            tile == magma_slope_right or
            tile == grass_slope_right or
            tile == dirt_slope_right
end

function is_left_slope_tile(tile)
    return tile == stone_slope_left or
            tile == magma_slope_left or
            tile == grass_slope_left or
            tile == dirt_slope_left
end

-- helper function to calculate y position on a slope
function get_slope_collision(tile, x)
    local slope_height = 0
    if tile == dirt_slope_right or tile == magma_slope_right or tile == grass_slope_right or tile == stone_slope_right then
        slope_height = (x % 8)
    elseif tile == dirt_slope_left or tile == magma_slope_left or tile == grass_slope_left or tile == stone_slope_left then
        slope_height = 8 - (x % 8)
    end
    return slope_height
end

function get_slope_y(tile, x)
    local slope_height = 0
    if is_right_slope_tile(tile) then
        slope_height = 0.5 * (x % 8)
    elseif is_left_slope_tile(tile) then
        slope_height = -0.5 * (x % 8) + 8
    end
    return slope_height
end

function update_character()
    local new_x = character.x
    local new_y = character.y

    if btn(0) then -- left arrow key
        new_x = character.x - character.speed
    end
    if btn(1) then -- right arrow key
        new_x = character.x + character.speed
    end
    -- add jump input handling
    if btnp(4) and character.vy == 0 then
        character.vy = character.jump_strength
    end

    -- apply gravity
    character.vy = character.vy + character.gravity
    new_y = character.y + character.vy

    -- check for horizontal collisions
    local x_tile = flr((new_x + 4) / 8)
    local y_tile = flr((character.y + 6) / 8)
    local tile_left = mget(x_tile, y_tile)
    local tile_right = mget(x_tile, y_tile)

    if not (is_solid_tile(tile_left) or is_solid_tile(tile_right)) then
        character.x = new_x
    end

    -- check for vertical collisions
    local x_tile = flr((character.x + 4) / 8)
    local y_tile_bottom = flr((new_y + 7) / 8)
    local y_tile_top = flr((new_y + 6) / 8)
    local tile_bottom = mget(x_tile, y_tile_bottom)
    local tile_top = mget(x_tile, y_tile_top)

    if is_solid_tile(tile_bottom) or is_solid_tile(tile_top) then
        character.vy = 0
    else
        local slope_bottom_y = get_slope_y(tile_bottom, character.x + 4)
        local slope_top_y = get_slope_y(tile_top, character.x + 4)

        if slope_bottom_y > 0 or slope_top_y > 0 then
            new_y = y_tile_bottom * 8 - slope_bottom_y - 7
            character.vy = 0
        end
        character.y = new_y
    end
end

function update_camera()
    camera_x = character.x - 64
    camera_y = character.y - 64
end

function draw_character()
    spr(character.sprite, character.x, character.y)
end

function holding_pattern(boss)
    -- calculate the horizontal movement range
    local left_bound = boss_start_position_x
    local right_bound = boss_start_position_x + boss.holding_pattern_width

    -- move the boss horizontally
    if boss.x >= right_bound then
        boss.direction = -1
    elseif boss.x <= left_bound then
        boss.direction = 1
    end

    boss.x = boss.x + boss.speed * boss.direction

    -- increment the earth_shake_timer and check if it's time to perform the earth shake move.
    boss.earth_shake_timer = boss.earth_shake_timer + 1
    if boss.earth_shake_timer >= 600 then -- 10 seconds * 60 frames per second
        boss.earth_shake_timer = 0
        boss.state = "earth_shake"
    end
end

function earth_shake(boss)
    -- move the boss down to the ground.
    local target_y = map_height * 8 - 8
    if boss.y < target_y then
        boss.y = boss.y + 2
    else
        -- stay on the ground for 2 seconds.
        boss.earth_shake_timer = boss.earth_shake_timer + 1
        if boss.earth_shake_timer >= 120 then -- 2 seconds * 60 frames per second
            boss.earth_shake_timer = 0
            boss.y = boss_start_position_y
            boss.state = "holding_pattern"
        end
    end
end

function vulnerability(boss)
    -- change the boss's sprite to the frowny face.
    boss.sprite = boss.frowny_sprite

    -- increment the vulnerability_timer and check if the invulnerability period is over.
    boss.vulnerability_timer = boss.vulnerability_timer + 1
    if boss.vulnerability_timer >= 180 then -- 3 seconds * 60 frames per second
        boss.vulnerability_timer = 0
        boss.invulnerable = false
        boss.state = "holding_pattern"
    end
end

-- update the check_boss_collision() function
function check_boss_collision()
    if boss.invulnerable or boss.defeated then
        return
    end

    if character.y + 1 == boss.y and character.x == boss.x then
        boss.health = boss.health - 1
        boss.invulnerable = true
        boss.state = "vulnerability"

        if boss.health <= 0 then
            boss.defeated = true
        end
    end
end

function update_boss()
    if boss.state == "holding_pattern" then
        holding_pattern(boss)
    elseif boss.state == "earth_shake" then
        earth_shake(boss)
    elseif boss.state == "vulnerability" then
        vulnerability(boss)
    end
end

-- update the draw_boss() function
function draw_boss()
    if not boss.defeated then
        spr(boss.sprite, boss.x, boss.y)
    end
end

-- draw the map in the _draw() function
function _draw()
    cls()
    camera(camera_x, camera_y)
    map(0, 0, 0, 0, map_width, map_height)
    draw_character()
    draw_boss()
end

function _update()
    update_character()
    update_camera()
    update_boss()
    check_boss_collision()
end

function _init()
end