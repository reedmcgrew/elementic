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
local coolled_magma = 7
local metal = 24
local galixy = 32
local mossy_stone = 14
local frozen_stone = 15
local snow = 25
local corrupted_stone = 4
local corrupted_stone_wall = 48


-- map dimensions
local map_width = 128
local map_height = 16

local character = {
    x = 1*8,
    y = 7*8,
    speed = 1,
    sprite = 3,
    vy = 0,
    gravity = 0.2,
    jump_strength = -2.5,
    health = 5,
    max_health = 5,
    invulnerable = false,
    invulnerable_timer = 0,
    invulnerability_duration = 2 * 30, -- 2 seconds in frames (60 frames per second)
    input = {
        left = 0,
        right = 1,
        jump = 4
    }
}

local boss_start_position_x = 7*8
local boss_start_position_y = 9*8
local boss_angry_sprite = 60
local boss_impaired_sprite = 17
local boss = {
    x = boss_start_position_x, -- initial x position
    y = boss_start_position_y, -- initial y position
    sprite = boss_angry_sprite, -- start with angry sprite
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

function is_damage_tile(tile)
    return tile == magma
end

function check_character_damage()
    -- Return if character is invulnerable
    if character.invulnerable then
        return
    end

    -- Check for collision with the boss
    local char_left_edge = character.x
    local char_right_edge = character.x + 7
    local char_top_edge = character.y
    local char_bottom_edge = character.y + 7

    local boss_left_edge = boss.x
    local boss_right_edge = boss.x + 7
    local boss_top_edge = boss.y
    local boss_bottom_edge = boss.y + 7

    local character_should_become_invulnerable = false -- Only become invulnerable if health is lost this cycle
    if char_right_edge >= boss_left_edge and char_left_edge <= boss_right_edge
            and char_bottom_edge >= boss_top_edge and char_top_edge <= boss_bottom_edge then
        -- Only decrease health if the character is not on top of the boss
        if not (char_bottom_edge == boss_top_edge) then
            character.health = character.health - 1
            character_should_become_invulnerable = true
        end
    end

    -- Check for collision with damage-producing tiles
    local x_tile = flr((character.x + 4) / 8)
    local y_tile = flr((character.y + 4) / 8)
    local tile = mget(x_tile, y_tile)

    if (tile == magma or tile == magma_layer_entrance) and character_should_become_invulnerable == false then
        character.health = character.health - 1
        character_should_become_invulnerable = true
    end

    -- If character health reaches zero, reset it to the max health and reset the position
    if character.health <= 0 then
        character.health = character.max_health
        character.x = 1 * 8
        character.y = 7 * 8
        character.vy = 0
    end

    -- Make the character invulnerable after taking damage
    if character_should_become_invulnerable then
        character.invulnerable = true
        character.invulnerable_timer = character.invulnerability_duration
    end
end


function character_collides_with_enemy()
    -- check if the character collides with the boss's side or bottom
    return not boss.defeated and
            character.x + 8 >= boss.x and character.x <= boss.x + 7 and
            character.y + 8 >= boss.y and character.y <= boss.y + 7
end

-- create a function to draw the health meter
function draw_health_meter()
    local meter_width = 5 * character.max_health
    local meter_height = 5
    local meter_x = 127 * 8 - meter_width
    local meter_y = 0

    -- draw the background (empty health meter)
    rectfill(meter_x, meter_y, meter_x + meter_width, meter_y + meter_height, 1)

    -- draw the filled part of the health meter (remaining health)
    local fill_width = meter_width * character.health / character.max_health
    rectfill(meter_x, meter_y, meter_x + fill_width, meter_y + meter_height, 8)
end

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

function update_character_horizontal_movement()
    local new_x = character.x

    if btn(character.input.left) then
        new_x = character.x - character.speed
    end
    if btn(character.input.right) then
        new_x = character.x + character.speed
    end

    -- Check for horizontal collisions
    local x_tile = flr((new_x + 4) / 8)
    local y_tile = flr((character.y + 6) / 8)
    local tile_left = mget(x_tile, y_tile)
    local tile_right = mget(x_tile, y_tile)

    if not (is_solid_tile(tile_left) or is_solid_tile(tile_right)) then
        character.x = new_x
    end
end

function update_character_vertical_movement()
    local new_y = character.y

    -- Add jump input handling
    if btnp(character.input.jump) and character.vy == 0 then
        character.vy = character.jump_strength
    end

    -- Apply gravity
    character.vy = character.vy + character.gravity
    new_y = character.y + character.vy

    -- Check for vertical collisions
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

-- Updated update_character function
function update_character()
    update_character_horizontal_movement()
    update_character_vertical_movement()
end

-- Add this function to your game loop (_update function)
function update_invulnerability()
    if character.invulnerable then
        character.invulnerable_timer = character.invulnerable_timer - 1
        if character.invulnerable_timer <= 0 then
            character.invulnerable = false
            character.invulnerable_timer = 0
        end
    end
end

function update_camera()
    camera_x = character.x - 64
    camera_y = character.y - 64
end

function draw_character()
    -- Only draw the character if it's not invulnerable or blinking
    if not character.invulnerable or (character.invulnerable and (flr(time() * 8) % 2 == 0)) then
        spr(character.sprite, character.x, character.y, 1, 1)
    end
end

function draw_character_info()
    local info_x = 2
    local info_y = 10

    print("Character Info:", info_x, info_y, 7)
    print("X: " .. character.x, info_x, info_y + 8, 7)
    print("Y: " .. character.y, info_x, info_y + 16, 7)
    print("Speed: " .. character.speed, info_x, info_y + 24, 7)
    print("Sprite: " .. character.sprite, info_x, info_y + 32, 7)
    print("Vy: " .. character.vy, info_x, info_y + 40, 7)
    print("Health: " .. character.health, info_x, info_y + 48, 7)
    print("Invulnerable: " .. tostring(character.invulnerable), info_x, info_y + 56, 7)
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
    boss.sprite = boss_impaired_sprite

    -- increment the vulnerability_timer and check if the invulnerability period is over.
    boss.vulnerability_timer = boss.vulnerability_timer + 1
    if boss.vulnerability_timer >= 180 then -- 3 seconds * 60 frames per second
        boss.vulnerability_timer = 0
        boss.invulnerable = false
        boss.sprite = boss_angry_sprite
        boss.state = "holding_pattern"
    end
end

-- update the check_boss_collision() function
function check_boss_collision()
    if boss.invulnerable or boss.defeated then
        return
    end

    local char_pixel_x = character.x + 5
    local char_bottom_edge = character.y + 8

    local boss_left_edge = boss.x
    local boss_right_edge = boss.x + 7
    local boss_top_edge = boss.y

    if char_bottom_edge == boss_top_edge
            and char_pixel_x >= boss_left_edge
            and char_pixel_x <= boss_right_edge then
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

-- Create a function to draw the health meter
function draw_health_meter()
    local meter_width = 5 * character.max_health
    local meter_height = 5
    local meter_x = (127 - character.max_health * 5)
    local meter_y = 0

    -- Draw the background (empty health meter)
    rectfill(meter_x, meter_y, meter_x + meter_width, meter_y + meter_height, 1)

    -- Draw the filled part of the health meter (remaining health)
    local fill_width = meter_width * character.health / character.max_health
    rectfill(meter_x, meter_y, meter_x + fill_width, meter_y + meter_height, 8)
end


-- draw the map in the _draw() function
function _draw()
    cls()

    -- Draw the map, character, and boss with the camera
    camera(camera_x, camera_y)
    map(0, 0, 0, 0, map_width, map_height)
    draw_character()
    draw_boss()

    -- Draw the health meter without camera adjustments
    camera(0, 0)
    draw_character_info() -- Add this line
    draw_health_meter()
end


function _update()
    update_character()
    update_camera()
    update_boss()
    check_boss_collision()
    check_character_damage()
    update_invulnerability()
end

function _init()
end