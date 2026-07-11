local QBCore = exports['qb-core']:GetCoreObject()

local function debugLog(...)
    if Config.Debug then
        print('[^2QBCore-Perms^7]', ...)
    end
end

-- Local cache of loaded permissions to prevent double-applying
local loadedPermissions = {}

--- Get the appropriate identifier for a player based on config
-- @param src number - Player server ID
-- @param playerData table - Player data from QBCore
-- @return string identifier, string identifierType
local function getPlayerIdentifier(src, playerData)
    if Config.UseLicenseId then
        local license = GetPlayerIdentifier(src, 'license') or playerData.license
        return license, 'license'
    else
        return playerData.citizenid, 'citizenid'
    end
end

--- Apply ACE principal for a permission
-- @param identifier string - Player's identifier
-- @param permission string - Permission level to apply
local function applyAcePrincipal(identifier, permission)
    if not identifier or not permission then return false end

    local success, err = pcall(function()
        ExecuteCommand(('add_principal identifier.%s qbcore.%s'):format(identifier, permission))
    end)

    if not success then
        debugLog('^1Failed to apply ACE principal:', err, '^7')
        return false
    end

    return true
end

--- Remove ACE principal for a permission
-- @param identifier string - Player's identifier
-- @param permission string|nil - Permission to remove, nil removes all qbcore.* principals
local function removeAcePrincipal(identifier, permission)
    if not identifier then return false end

    local success, err = pcall(function()
        if permission then
            ExecuteCommand(('remove_principal identifier.%s qbcore.%s'):format(identifier, permission))
        else
            -- Remove all known permission principals for this identifier
            for _, perm in ipairs(Config.PermissionLevels) do
                ExecuteCommand(('remove_principal identifier.%s qbcore.%s'):format(identifier, perm))
            end
        end
    end)

    if not success then
        debugLog('^1Failed to remove ACE principal:', err, '^7')
        return false
    end

    return true
end

-- ============================================
-- PUBLIC FUNCTIONS (override qb-core defaults)
-- ============================================

--- Add a permission to a player and persist to database
-- Replaces QBCore.Functions.AddPermission
-- @param source number - Player server ID
-- @param permission string - Permission level to grant
function QBCore.Functions.AddPermission(source, permission)
    local src = tonumber(source)
    if not src or src <= 0 then
        debugLog('^1Error: Invalid source in AddPermission^7')
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        debugLog('^1Error: Player not found for source', src, '^7')
        return
    end

    local identifier, identifierType = getPlayerIdentifier(src, Player.PlayerData)
    if not identifier then
        debugLog('^1Error: Could not resolve identifier for source', src, '^7')
        return
    end

    local cleanPermission = permission:lower()

    -- Store in memory
    QBCore.Config.Server.Permissions[identifier] = {
        identifier = identifier,
        permission = cleanPermission
    }

    -- Persist to database
    DB.UpsertPermission(
        GetPlayerName(src),
        identifier,
        cleanPermission,
        identifierType
    )

    -- Apply ACE principal
    applyAcePrincipal(identifier, cleanPermission)

    -- Refresh commands for player
    QBCore.Commands.Refresh(src)

    -- Notify client
    TriggerClientEvent('QBCore:Client:OnPermissionUpdate', src, cleanPermission)

    debugLog(('Permission ^3%s^7 added for ^5%s^7 (^2%s^7)'):format(
        cleanPermission, GetPlayerName(src), identifier
    ))
end

--- Remove a permission from a player
-- Replaces QBCore.Functions.RemovePermission
-- @param source number - Player server ID
-- @param permission string|nil - Specific permission to remove, nil removes all
function QBCore.Functions.RemovePermission(source, permission)
    local src = tonumber(source)
    if not src or src <= 0 then
        debugLog('^1Error: Invalid source in RemovePermission^7')
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        debugLog('^1Error: Player not found for source', src, '^7')
        return
    end

    local identifier = getPlayerIdentifier(src, Player.PlayerData)
    if not identifier then
        debugLog('^1Error: Could not resolve identifier for source', src, '^7')
        return
    end

    if permission then
        local cleanPermission = permission:lower()

        if IsPlayerAceAllowed(src, cleanPermission) then
            -- Remove from database
            DB.RemovePermission(identifier, cleanPermission)

            -- Remove ACE principal
            removeAcePrincipal(identifier, cleanPermission)

            -- Remove from memory
            if QBCore.Config.Server.Permissions[identifier] then
                QBCore.Config.Server.Permissions[identifier] = nil
            end

            -- Refresh commands
            QBCore.Commands.Refresh(src)

            debugLog(('Permission ^3%s^7 removed from ^5%s^7'):format(
                cleanPermission, GetPlayerName(src)
            ))
        end
    else
        -- Remove all permissions
        DB.RemovePermission(identifier, nil)

        -- Remove ACE principals
        removeAcePrincipal(identifier, nil)

        -- Clear from memory
        QBCore.Config.Server.Permissions[identifier] = nil

        -- Refresh commands
        QBCore.Commands.Refresh(src)

        debugLog(('All permissions removed from ^5%s^7'):format(GetPlayerName(src)))
    end
end

--- Check if a player has a specific permission
-- @param source number - Player server ID
-- @param permission string - Permission to check
-- @return boolean
function QBCore.Functions.HasPermission(source, permission)
    local src = tonumber(source)
    if not src or src <= 0 then return false end

    return IsPlayerAceAllowed(src, permission)
end

-- ============================================
-- EVENT HANDLERS
-- ============================================

--- Apply stored permissions when a player loads
-- Critical: syncs DB permissions on every player join
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    -- Validate player data BEFORE using it (fixed from original PR)
    if not Player or not Player.PlayerData then
        debugLog('^1Error: PlayerLoaded triggered with invalid player data^7')
        return
    end

    local src = Player.PlayerData.source
    if not src then
        debugLog('^1Error: PlayerLoaded - source is nil^7')
        return
    end

    local identifier = getPlayerIdentifier(src, Player.PlayerData)
    if not identifier then
        debugLog('^1Error: Could not resolve identifier for loaded player^7')
        return
    end

    -- Prevent double-loading (cache check)
    if loadedPermissions[src] then
        debugLog(('Permissions already loaded for source ^5%s^7'):format(src))
        return
    end

    DB.GetPermissions(identifier, function(result)
        if not result or #result == 0 then
            debugLog(('No stored permissions found for ^5%s^7'):format(identifier))
            return
        end

        loadedPermissions[src] = true

        for _, row in ipairs(result) do
            local permission = row.permission
            if permission then
                applyAcePrincipal(identifier, permission)
                TriggerClientEvent('QBCore:Client:OnPermissionUpdate', src, permission)
                debugLog(('Applied permission ^3%s^7 to ^5%s^7'):format(permission, identifier))
            end
        end

        QBCore.Commands.Refresh(src)

        debugLog(('Permissions synced for ^2%s^7 (source: ^5%s^7)'):format(
            GetPlayerName(src) or 'Unknown', src
        ))
    end)
end)

--- Clean up cache when player drops
AddEventHandler('playerDropped', function()
    local src = source
    if loadedPermissions[src] then
        loadedPermissions[src] = nil
        debugLog(('Cleaned permission cache for source ^5%s^7'):format(src))
    end
end)

-- ============================================
-- ADMIN COMMANDS
-- ============================================

QBCore.Commands.Add('setperm', 'Set player permission level (Admin Only)', {
    { name = 'id', help = 'Player ID' },
    { name = 'permission', help = 'Permission level (user/admin/god/moderator)' }
}, true, function(source, args)
    local src = source
    local targetId = tonumber(args[1])
    local permission = args[2] and args[2]:lower()

    if not targetId or not permission then
        TriggerClientEvent('QBCore:Notify', src, 'Usage: /setperm [id] [permission]', 'error')
        return
    end

    if not QBCore.Functions.HasPermission(src, 'god') and not QBCore.Functions.HasPermission(src, 'admin') then
        TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error')
        return
    end

    local validPerm = false
    for _, perm in ipairs(Config.PermissionLevels) do
        if perm == permission then
            validPerm = true
            break
        end
    end

    if not validPerm then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid permission level', 'error')
        return
    end

    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
        return
    end

    QBCore.Functions.AddPermission(targetId, permission)
    TriggerClientEvent('QBCore:Notify', src,
        ('Permission %s set for %s'):format(permission, targetPlayer.PlayerData.charinfo.firstname),
        'success'
    )
end, 'admin')

QBCore.Commands.Add('removeperm', 'Remove all permissions from player (Admin Only)', {
    { name = 'id', help = 'Player ID' }
}, true, function(source, args)
    local src = source
    local targetId = tonumber(args[1])

    if not targetId then
        TriggerClientEvent('QBCore:Notify', src, 'Usage: /removeperm [id]', 'error')
        return
    end

    if not QBCore.Functions.HasPermission(src, 'god') and not QBCore.Functions.HasPermission(src, 'admin') then
        TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error')
        return
    end

    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
        return
    end

    QBCore.Functions.RemovePermission(targetId, nil)
    TriggerClientEvent('QBCore:Notify', src,
        ('Permissions removed from %s'):format(targetPlayer.PlayerData.charinfo.firstname),
        'success'
    )
end, 'admin')
