# QBCore Persistent Permissions Edit

Directly edit `qb-core` to save permissions in the database and restore them on player join. No separate resource needed.

---

## 1. Database Setup

Run this SQL to create the permissions table:

```sql
CREATE TABLE IF NOT EXISTS `permissions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL,
    `identifier` VARCHAR(255) NOT NULL,
    `permission` VARCHAR(50) NOT NULL,
    `type` VARCHAR(20) NOT NULL DEFAULT 'citizenid',
    UNIQUE KEY `unique_identifier` (`identifier`)
);
```

---

## 2. Edit `qb-core/server/functions.lua`

### Step 2a — Replace `QBCore.Functions.AddPermission`

**Find this (original):**

```lua
---Add permission for player
---@param source any
---@param permission string
function QBCore.Functions.AddPermission(source, permission)
    if not IsPlayerAceAllowed(source, permission) then
        ExecuteCommand(('add_principal player.%s qbcore.%s'):format(source, permission))
        QBCore.Commands.Refresh(source)
    end
end
```

**Replace with:**

```lua
---Add permission for player (database-backed)
---@param source any
---@param permission string
function QBCore.Functions.AddPermission(source, permission)
    local src = tonumber(source)
    if not src or src <= 0 then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- CONFIG: set to true for license-based, false for citizenid-based
    local UseLicenseId = false

    local identifier, idType
    if UseLicenseId then
        identifier = QBCore.Functions.GetIdentifier(src, 'license') or Player.PlayerData.license
        idType = 'license'
    else
        identifier = Player.PlayerData.citizenid
        idType = 'citizenid'
    end

    if not identifier then return end

    local cleanPermission = permission:lower()

    -- Store in memory
    QBCore.Config.Server.Permissions[identifier] = {
        identifier = identifier,
        permission = cleanPermission
    }

    -- Persist to database
    MySQL.Async.execute('DELETE FROM permissions WHERE identifier = ?', { identifier }, function()
        MySQL.Async.insert(
            'INSERT INTO permissions (name, identifier, permission, type) VALUES (?, ?, ?, ?)',
            { GetPlayerName(src), identifier, cleanPermission, idType }
        )
    end)

    -- Apply ACE principal (uses identifier, not player source)
    ExecuteCommand(('add_principal identifier.%s qbcore.%s'):format(identifier, cleanPermission))
    QBCore.Commands.Refresh(src)

    -- Notify client
    TriggerClientEvent('QBCore:Client:OnPermissionUpdate', src, cleanPermission)
end
```

---

### Step 2b — Replace `QBCore.Functions.RemovePermission`

**Find this (original):**

```lua
---Remove permission from player
---@param source any
---@param permission string
function QBCore.Functions.RemovePermission(source, permission)
    if permission then
        if IsPlayerAceAllowed(source, permission) then
            ExecuteCommand(('remove_principal player.%s qbcore.%s'):format(source, permission))
            QBCore.Commands.Refresh(source)
        end
    else
        for _, v in pairs(QBCore.Config.Server.Permissions) do
            if IsPlayerAceAllowed(source, v) then
                ExecuteCommand(('remove_principal player.%s qbcore.%s'):format(source, v))
                QBCore.Commands.Refresh(source)
            end
        end
    end
end
```

**Replace with:**

```lua
---Remove permission from player (database-backed)
---@param source any
---@param permission string
function QBCore.Functions.RemovePermission(source, permission)
    local src = tonumber(source)
    if not src or src <= 0 then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- CONFIG: set to true for license-based, false for citizenid-based
    local UseLicenseId = false

    local identifier
    if UseLicenseId then
        identifier = QBCore.Functions.GetIdentifier(src, 'license') or Player.PlayerData.license
    else
        identifier = Player.PlayerData.citizenid
    end

    if not identifier then return end

    if permission then
        local cleanPermission = permission:lower()

        -- Remove from database
        MySQL.Async.execute('DELETE FROM permissions WHERE identifier = ? AND permission = ?',
            { identifier, cleanPermission })

        -- Remove ACE principal
        ExecuteCommand(('remove_principal identifier.%s qbcore.%s'):format(identifier, cleanPermission))

        -- Remove from memory
        if QBCore.Config.Server.Permissions[identifier] then
            QBCore.Config.Server.Permissions[identifier] = nil
        end

        QBCore.Commands.Refresh(src)
    else
        -- Remove all permissions
        MySQL.Async.execute('DELETE FROM permissions WHERE identifier = ?', { identifier })

        -- Remove all ACE principals for this identifier
        for _, perm in ipairs(QBCore.Config.Server.Permissions) do
            ExecuteCommand(('remove_principal identifier.%s qbcore.%s'):format(identifier, perm))
        end

        -- Clear from memory
        QBCore.Config.Server.Permissions[identifier] = nil

        QBCore.Commands.Refresh(src)
    end
end
```

---

### Step 2c — Replace `QBCore.Functions.HasPermission`

**Find this (original):**

```lua
---Check if player has permission
---@param source any
---@param permission string
---@return boolean
function QBCore.Functions.HasPermission(source, permission)
    if type(permission) == 'string' then
        if IsPlayerAceAllowed(source, permission) then return true end
    elseif type(permission) == 'table' then
        for _, permLevel in pairs(permission) do
            if IsPlayerAceAllowed(source, permLevel) then return true end
        end
    end

    return false
end
```

**Replace with:**

```lua
---Check if player has permission
---@param source any
---@param permission string
---@return boolean
function QBCore.Functions.HasPermission(source, permission)
    local src = tonumber(source)
    if not src or src <= 0 then return false end

    if type(permission) == 'string' then
        if IsPlayerAceAllowed(src, permission) then return true end
    elseif type(permission) == 'table' then
        for _, permLevel in pairs(permission) do
            if IsPlayerAceAllowed(src, permLevel) then return true end
        end
    end

    return false
end
```

---

### Step 2d — Replace `QBCore.Functions.GetPermission`

**Find this (original):**

```lua
---Get the players permissions
---@param source any
---@return table
function QBCore.Functions.GetPermission(source)
    local src = source
    local perms = {}
    for _, v in pairs(QBCore.Config.Server.Permissions) do
        if IsPlayerAceAllowed(src, v) then
            perms[v] = true
        end
    end
    return perms
end
```

**Replace with:**

```lua
---Get the players permissions
---@param source any
---@return table
function QBCore.Functions.GetPermission(source)
    local src = tonumber(source)
    if not src or src <= 0 then return {} end

    local perms = {}
    for _, v in pairs(QBCore.Config.Server.Permissions) do
        if IsPlayerAceAllowed(src, v) then
            perms[v] = true
        end
    end
    return perms
end
```

---

## 3. Edit `qb-core/server/events.lua`

### Step 3a — Add permission loading when player joins

**Find this event (around line 230):**

```lua
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    if not QBCore.Players[src] then return end
    TriggerClientEvent('QBCore:Client:OnPlayerLoaded', src)
end)
```

**Replace with:**

```lua
-- Local cache to prevent double-loading permissions
local loadedPermissions = {}

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    if not QBCore.Players[src] then return end

    -- Load and apply stored permissions from database
    local Player = QBCore.Players[src]
    if Player and Player.PlayerData then
        -- CONFIG: must match the setting in functions.lua
        local UseLicenseId = false

        local identifier
        if UseLicenseId then
            identifier = QBCore.Functions.GetIdentifier(src, 'license') or Player.PlayerData.license
        else
            identifier = Player.PlayerData.citizenid
        end

        if identifier and not loadedPermissions[src] then
            MySQL.Async.fetchAll('SELECT permission FROM permissions WHERE identifier = ?', { identifier }, function(result)
                if result and #result > 0 then
                    loadedPermissions[src] = true

                    for _, row in ipairs(result) do
                        local perm = row.permission
                        if perm then
                            ExecuteCommand(('add_principal identifier.%s qbcore.%s'):format(identifier, perm))
                            TriggerClientEvent('QBCore:Client:OnPermissionUpdate', src, perm)
                        end
                    end

                    QBCore.Commands.Refresh(src)
                end
            end)
        end
    end

    TriggerClientEvent('QBCore:Client:OnPlayerLoaded', src)
end)
```

---

### Step 3b — Clean up cache on player drop

**Find this event (around line 12):**

```lua
AddEventHandler('playerDropped', function(reason)
    local src = source
    if not QBCore.Players[src] then return end
    local player = QBCore.Players[src]
    TriggerEvent('qb-log:server:CreateLog', 'joinleave', 'Dropped', 'red', '**' .. GetPlayerName(src) .. '** (' .. player.PlayerData.license .. ') left..' .. '\n **Reason:** ' .. reason)
    player.Functions.Save()
    TriggerEvent('QBCore:Server:PlayerDropped', src)
    TriggerEvent('QBCore:Server:OnPlayerUnload', src)
    QBCore.Player_Buckets[player.PlayerData.license] = nil
    QBCore.PlayersByCitizenId[player.PlayerData.citizenid] = nil
    QBCore.Players[src] = nil
end)
```

**Replace with:**

```lua
AddEventHandler('playerDropped', function(reason)
    local src = source
    if not QBCore.Players[src] then return end
    local player = QBCore.Players[src]
    TriggerEvent('qb-log:server:CreateLog', 'joinleave', 'Dropped', 'red', '**' .. GetPlayerName(src) .. '** (' .. player.PlayerData.license .. ') left..' .. '\n **Reason:** ' .. reason)
    player.Functions.Save()
    TriggerEvent('QBCore:Server:PlayerDropped', src)
    TriggerEvent('QBCore:Server:OnPlayerUnload', src)
    QBCore.Player_Buckets[player.PlayerData.license] = nil
    QBCore.PlayersByCitizenId[player.PlayerData.citizenid] = nil
    QBCore.Players[src] = nil

    -- Clean up permission cache
    if loadedPermissions[src] then
        loadedPermissions[src] = nil
    end
end)
```

---

## 4. (Optional) Update Admin Commands

The built-in `/addpermission` and `/removepermission` commands are restricted to `god` only. To allow `admin` to use them too, edit `qb-core/server/commands.lua`:

**Find:**

```lua
QBCore.Commands.Add('addpermission', ...
```

Change the last argument from `'god'` to `'admin'` (or `{'god', 'admin'}`).

Same for `removepermission`.

---

## How It Works

| Original | New |
|----------|-----|
| Uses `player.%s` ACE principal (tied to session) | Uses `identifier.%s` ACE principal (tied to citizenid/license) |
| Permissions lost on restart | Saved to `permissions` table, restored on join |
| No DB storage | MySQL table with unique identifier index |

---

## Troubleshooting

**Permissions not applying on join?**
- Check that `UseLicenseId` matches in BOTH `functions.lua` and `events.lua`
- Verify the `permissions` table exists in your database
- Check server console for MySQL errors

**ACE principals not working?**
- Make sure your `server.cfg` has: `add_ace qbcore.god command allow` (and same for admin, moderator)
- Restart the server fully after changing ACE settings

**Want to switch from CitizenID to License?**
- Change `UseLicenseId = false` to `UseLicenseId = true` in both files
- Existing DB rows will need their `type` column updated or re-created
