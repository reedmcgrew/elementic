local debugInfoOn = false

---
--- Terrain Logic
---
local dirt = 11
local magma = 51
local magma_layer_entrance = 52
local grass = 43
local stone = 8
local coolled_magma = 7
local metal = 24
local galixy = 32
local mossy_stone = 14
local frozen_stone = 15
local snow = 25
local corrupted_stone = 4
local corrupted_stone_wall = 48
local cloud = 44

-- map dimensions
local map_width = 128
local map_height = 16

function is_damage_tile(tile)
    return tile == magma
end

function is_solid_tile(tile)
    return tile == stone or
            tile == magma or
            tile == grass or
            tile == dirt or
            tile == frozen_stone or
            tile == snow or
            tile == coolled_magma or
            tile == metal or
            tile == galixy or
            tile == mossy_stone or
            tile == corrupted_stone or
            tile == corrupted_stone_wall or
            tile == cloud
end

---
--- Other Constants
---
local METER_COLOR = {
    GREEN = 11,
    RED = 8
}

---
--- Game State
---
local character = {
    -- Standard entity state
    x = 1*8,
    y = 7*8,
    speed = 1,
    sprite = 3,
    health = 5,
    max_health = 5,
    invulnerable = false,
    invulnerable_timer = 0,
    invulnerability_duration = 2 * 30, -- 2 seconds in frames (60 frames per second)

    -- Main character jump mechanics settings
    vy = 0,
    gravity = 0.2,
    jump_strength = -2.5,

    -- Double Jump
    double_jump_enabled = false,
    jumps = 0,
    max_jumps = 2,  -- The first jump plus one more

    -- Inputs
    input = {
        left = 0,
        right = 1,
        jump = 4
    }
}

local lava_boss_start_x = 7*8
local lava_boss_start_y = 9*8
local lava_boss = {
    -- Standard entity state
    x = lava_boss_start_x, -- initial x position
    y = lava_boss_start_y, -- initial y position
    speed = 0.5, -- movement speed
    sprite = 60,
    health = 3, -- initial total health
    max_health = 3,
    invulnerable = false,
    invulnerable_timer = 0,
    invulnerability_duration = 2 * 30,

    -- Lava-boss-specific state
    defeated = false,
    state = "holding_pattern",
    holding_pattern_width = 8*8,
    earth_shake_timer = 0,
    direction = 1 -- initial direction (1 for right, -1 for left)
}

---
--- Character Logic
---
function update_character(character)
    update_character_horizontal_movement(character)
    update_character_vertical_movement(character)
end

function update_character_vertical_movement(character)
    local new_y = character.y

    -- Add jump input handling
    if btnp(character.input.jump) then
        -- If we're on the ground or have double jump enabled and haven't used up all our jumps
        if character.vy == 0 or (character.double_jump_enabled and character.jumps < character.max_jumps) then
            character.vy = character.jump_strength
            character.jumps = character.jumps + 1
        end
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
        character.jumps = 0  -- Reset the jump counter when we touch the ground
    else
        character.y = new_y
    end
end


function update_character_horizontal_movement(character)
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

function handle_entity_invulnerability(entity)
    if entity.invulnerable then
        entity.invulnerable_timer = entity.invulnerable_timer - 1
        if entity.invulnerable_timer <= 0 then
            entity.invulnerable = false
            entity.invulnerable_timer = 0
        end
    end
end

---
--- Boss Logic
---
function update_boss(boss)
    if boss.state == "holding_pattern" then
        holding_pattern(boss)
    elseif boss.state == "earth_shake" then
        earth_shake(boss)
    elseif boss.state == "vulnerability" then
        handle_entity_invulnerability(boss)
    end
end

function holding_pattern(boss)
    -- calculate the horizontal movement range
    local left_bound = lava_boss_start_x
    local right_bound = lava_boss_start_x + boss.holding_pattern_width

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
    local target_y = map_height * 8 - 8*5
    if boss.y < target_y then
        boss.y = boss.y + 2
    else
        -- stay on the ground for 2 seconds.
        boss.earth_shake_timer = boss.earth_shake_timer + 1
        if boss.earth_shake_timer >= 120 then -- 2 seconds * 60 frames per second
            boss.earth_shake_timer = 0
            boss.y = lava_boss_start_y
            boss.state = "holding_pattern"
        end
    end
end

---
--- Character + Boss Interactions
---
function handle_boss_collision(character, boss)
    if boss.invulnerable or boss.defeated then
        return
    end

    local char_pixel_x = character.x + 4
    local char_bottom_edge = character.y + 8

    local boss_left_edge = boss.x
    local boss_right_edge = boss.x + 7
    local boss_top_edge = boss.y

    if (char_bottom_edge < boss_top_edge and char_bottom_edge > boss_top_edge - 4)
            and char_pixel_x >= boss_left_edge
            and char_pixel_x <= boss_right_edge then
        boss.health = boss.health - 1
        boss.invulnerable = true
        boss.invulnerable_timer = lava_boss.invulnerability_duration

        -- Bounce the character off the boss's head.
        character.vy = character.jump_strength

        if boss.health <= 0 then
            boss.defeated = true
        end
    end
end

function check_character_damage(character, boss)
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
    if not boss.defeated and char_right_edge >= boss_left_edge and char_left_edge <= boss_right_edge
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

---
---  Main Drawing Logic
---
function _draw()
    cls()
    draw_map()
    draw_character(character)
    draw_boss(lava_boss, character)

    if debugInfoOn then
        draw_entity_debug_info(character)
    end
end

function update_character_camera(character)
    character_cam_x = character.x - 64
    character_cam_y = character.y - 64
end

function draw_map()
    -- Draw map using the camera wrt the character.
    camera(character_cam_x, character_cam_y)
    map(0, 0, 0, 0, map_width, map_height)
end

function draw_character(character)
    draw_entity(character)
    draw_health_meter(character, 0, METER_COLOR.GREEN)
end

function draw_boss(boss, character)
    if not boss.defeated and abs(character.x - boss.x) <= 9*8 and character.y >= lava_boss_start_y then
        draw_entity(boss)
        draw_health_meter(boss, 1, METER_COLOR.RED)
    end
end

function draw_entity(entity)
    -- Don't draw the entity if it is defeated
    if entity.defeated ~= nil and entity.defeated == true then
        return
    end

    -- Draw entity using the camera wrt the main character.
    camera(character_cam_x, character_cam_y)

    -- Only draw the entity (character or boss) if it's not invulnerable or blinking
    if not entity.invulnerable or (entity.invulnerable and (flr(time() * 8) % 2 == 0)) then
        spr(entity.sprite, entity.x, entity.y, 1, 1)
    end
end

function draw_entity_debug_info(entity)
    local y_offset = 8
    local line = 0
    for key, value in pairs(entity) do
        print(key .. ": " .. tostring(value), 1, y_offset * line, 7)
        line = line + 1
    end
end

function draw_health_meter(entity, line, meter_color)
    -- Draw the health meter without camera adjustments
    camera(0, 0)
    local y_offset = 8
    local meter_width = 5 * entity.max_health
    local meter_height = 5
    local meter_x = (127 - entity.max_health * 5)
    local meter_y = y_offset*line

    -- Draw the background (empty health meter)
    rectfill(meter_x, meter_y, meter_x + meter_width, meter_y + meter_height, 1)

    -- Draw the filled part of the health meter (remaining health)
    local fill_width = meter_width * entity.health / entity.max_health
    rectfill(meter_x, meter_y, meter_x + fill_width, meter_y + meter_height, meter_color)
end

---
--- Main Game State Update Logic
---
function _update()
    -- Movement and Collision Detection
    update_character(character)
    update_character_camera(character)
    update_boss(lava_boss)

    -- Damage Handling
    handle_boss_collision(character, lava_boss)
    check_character_damage(character, lava_boss)
    handle_entity_invulnerability(character)
    handle_entity_invulnerability(lava_boss)
end

---
--- Initialize Game State
---
function _init()
end