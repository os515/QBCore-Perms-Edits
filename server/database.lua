DB = {}

local function debugLog(...)
    if Config.Debug then
        print('[^2QBCore-Perms^7]', ...)
    end
end

--- Get all stored permissions for a player from the database
-- @param identifier string - The player's identifier (citizenid or license)
-- @param callback function - Callback receiving results array or nil
function DB.GetPermissions(identifier, callback)
    if not identifier then
        debugLog('^1Error: Cannot get permissions - identifier is nil^7')
        if callback then callback({}) end
        return
    end

    MySQL.Async.fetchAll('SELECT permission FROM permissions WHERE identifier = ?', {
        identifier
    }, function(result)
        if callback then
            callback(result or {})
        end
    end)
end

--- Insert or update a permission in the database
-- @param name string - Player's name
-- @param identifier string - The player's identifier
-- @param permission string - Permission level
-- @param identifierType string - 'citizenid' or 'license'
-- @param callback function - Optional callback
function DB.UpsertPermission(name, identifier, permission, identifierType, callback)
    if not identifier or not permission then
        debugLog('^1Error: Cannot upsert permission - missing identifier or permission^7')
        if callback then callback(false) end
        return
    end

    MySQL.Async.execute('DELETE FROM permissions WHERE identifier = ?', { identifier }, function()
        MySQL.Async.insert(
            'INSERT INTO permissions (name, identifier, permission, type) VALUES (?, ?, ?, ?)',
            { name, identifier, permission:lower(), identifierType },
            function(insertId)
                debugLog(('Permission ^3%s^7 saved for ^5%s^7'):format(permission, identifier))
                if callback then callback(insertId ~= nil) end
            end
        )
    end)
end

--- Remove a specific permission or all permissions for a player
-- @param identifier string - The player's identifier
-- @param permission string|nil - Specific permission to remove, or nil to remove all
-- @param callback function - Optional callback receiving success boolean
function DB.RemovePermission(identifier, permission, callback)
    if not identifier then
        debugLog('^1Error: Cannot remove permission - identifier is nil^7')
        if callback then callback(false) end
        return
    end

    if permission then
        MySQL.Async.execute(
            'DELETE FROM permissions WHERE identifier = ? AND permission = ?',
            { identifier, permission:lower() },
            function(rowsChanged)
                debugLog(('Permission ^3%s^7 removed for ^5%s^7'):format(permission, identifier))
                if callback then callback(rowsChanged > 0) end
            end
        )
    else
        MySQL.Async.execute(
            'DELETE FROM permissions WHERE identifier = ?',
            { identifier },
            function(rowsChanged)
                debugLog(('All permissions removed for ^5%s^7'):format(identifier))
                if callback then callback(rowsChanged > 0) end
            end
        )
    end
end
