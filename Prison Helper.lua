-- Автопилот для вертолёта (с использованием setVirtualKeyDown)
require "lib.moonloader"
local vkeys = require "vkeys" -- предполагается, что setVirtualKeyDown доступна через vkeys

local target = {x = 0, y = 0, z = 0}
local autopilot_enabled = false

-- Проверка, находится ли игрок в вертолёте
function isPlayerInAnyHeli()
    local ped = playerPed
    if not isCharInAnyCar(ped) then return false end
    local veh = storeCarCharIsInNoSave(ped)
    if not doesVehicleExist(veh) then return false end
    local model = getCarModel(veh)
    local heli_models = {
        [417] = true, [425] = true, [447] = true, [465] = true, [469] = true,
        [487] = true, [488] = true, [497] = true, [548] = true, [563] = true,
    }
    return heli_models[model] or false
end

-- Получить текущий автомобиль игрока
function getPlayerCar()
    local ped = playerPed
    if isCharInAnyCar(ped) then
        return storeCarCharIsInNoSave(ped)
    end
    return nil
end

-- Получить координаты метки
function getGpsCoordinates()
    if getTargetBlipCoordinates then
        local success, x, y, z = getTargetBlipCoordinates()
        if success then return x, y, z end
    end
    return nil
end

function main()
    if not isSampLoaded() then return end
    while not isSampAvailable() do wait(0) end

    sampAddChatMessage("Автопилот вертолёта (setVirtualKeyDown) загружен.", -1)
    sampAddChatMessage("Команды: /flyon (по метке), /flyto X Y Z, /flyoff", -1)

    sampRegisterChatCommand("flyon", function()
        if not isPlayerInAnyHeli() then
            sampAddChatMessage("Вы должны находиться в вертолёте.", -1)
            return
        end
        local x, y, z = getGpsCoordinates()
        if not x then
            sampAddChatMessage("Не удалось получить координаты метки. Используйте /flyto X Y Z.", -1)
            return
        end
        target.x, target.y, target.z = x, y, z
        autopilot_enabled = true
        sampAddChatMessage(string.format("Автопилот включён. Цель: (%.2f, %.2f, %.2f)", x, y, z), -1)
    end)

    sampRegisterChatCommand("flyto", function(params)
        if not isPlayerInAnyHeli() then
            sampAddChatMessage("Вы должны находиться в вертолёте.", -1)
            return
        end
        local x, y, z = params:match("([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)")
        if not (x and y and z) then
            sampAddChatMessage("Использование: /flyto X Y Z", -1)
            return
        end
        target.x, target.y, target.z = tonumber(x), tonumber(y), tonumber(z)
        autopilot_enabled = true
        sampAddChatMessage(string.format("Автопилот включён. Цель: (%.2f, %.2f, %.2f)", target.x, target.y, target.z), -1)
    end)

    sampRegisterChatCommand("flyoff", function()
        autopilot_enabled = false
        -- Отпускаем все клавиши при выключении
        setVirtualKeyDown(vkeys.VK_NUMPAD8, false)
        setVirtualKeyDown(vkeys.VK_NUMPAD9, false)
        setVirtualKeyDown(vkeys.VK_NUMPAD3, false)
        setVirtualKeyDown(vkeys.VK_LEFT, false)
        setVirtualKeyDown(vkeys.VK_RIGHT, false)
        sampAddChatMessage("Автопилот выключен.", -1)
    end)

    -- Основной цикл
    while true do
        wait(0)

        if autopilot_enabled and isPlayerInAnyHeli() then
            local vehicle = getPlayerCar()
            if vehicle and doesVehicleExist(vehicle) then
                local x, y, z = getCarCoordinates(vehicle)
                local rz = getCarHeading(vehicle)

                local dx = target.x - x
                local dy = target.y - y
                local dz = (target.z + 15) - z
                local dist = math.sqrt(dx*dx + dy*dy + dz*dz)

                -- Управление высотой
                if z < target.z + 12 then
                    setVirtualKeyDown(vkeys.VK_NUMPAD9, true)  -- вверх
                    setVirtualKeyDown(vkeys.VK_NUMPAD3, false)
                elseif z > target.z + 18 then
                    setVirtualKeyDown(vkeys.VK_NUMPAD3, true)  -- вниз
                    setVirtualKeyDown(vkeys.VK_NUMPAD9, false)
                else
                    setVirtualKeyDown(vkeys.VK_NUMPAD9, false)
                    setVirtualKeyDown(vkeys.VK_NUMPAD3, false)
                end

                -- Управление направлением и движением
                if rz then
                    local target_angle = math.atan2(dy, dx) * 180 / math.pi
                    if target_angle < 0 then target_angle = target_angle + 360 end

                    local angle_diff = target_angle - rz
                    if angle_diff > 180 then angle_diff = angle_diff - 360
                    elseif angle_diff < -180 then angle_diff = angle_diff + 360 end

                    if math.abs(angle_diff) > 5 then
                        -- Поворачиваем
                        if angle_diff > 0 then
                            setVirtualKeyDown(vkeys.VK_RIGHT, true)
                            setVirtualKeyDown(vkeys.VK_LEFT, false)
                        else
                            setVirtualKeyDown(vkeys.VK_LEFT, true)
                            setVirtualKeyDown(vkeys.VK_RIGHT, false)
                        end
                        setVirtualKeyDown(vkeys.VK_NUMPAD8, false) -- не едем вперёд при повороте
                    else
                        -- Летим прямо
                        setVirtualKeyDown(vkeys.VK_RIGHT, false)
                        setVirtualKeyDown(vkeys.VK_LEFT, false)
                        setVirtualKeyDown(vkeys.VK_NUMPAD8, true) -- вперёд
                    end
                else
                    -- Если угол не получен, просто пытаемся лететь вперёд
                    setVirtualKeyDown(vkeys.VK_NUMPAD8, true)
                    setVirtualKeyDown(vkeys.VK_LEFT, false)
                    setVirtualKeyDown(vkeys.VK_RIGHT, false)
                end

                -- Прибытие
                if dist < 20 then
                    sampAddChatMessage("Вы прибыли к цели. Автопилот отключён.", -1)
                    autopilot_enabled = false
                    -- Отпускаем клавиши
                    setVirtualKeyDown(vkeys.VK_NUMPAD8, false)
                    setVirtualKeyDown(vkeys.VK_NUMPAD9, false)
                    setVirtualKeyDown(vkeys.VK_NUMPAD3, false)
                    setVirtualKeyDown(vkeys.VK_LEFT, false)
                    setVirtualKeyDown(vkeys.VK_RIGHT, false)
                end
            end
        else
            -- Если автопилот выключен или нет вертолёта, убеждаемся, что клавиши отпущены
            setVirtualKeyDown(vkeys.VK_NUMPAD8, false)
            setVirtualKeyDown(vkeys.VK_NUMPAD9, false)
            setVirtualKeyDown(vkeys.VK_NUMPAD3, false)
            setVirtualKeyDown(vkeys.VK_LEFT, false)
            setVirtualKeyDown(vkeys.VK_RIGHT, false)
        end
    end
end