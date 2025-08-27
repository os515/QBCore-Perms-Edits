# QBCore-Perms-Edits
This edit make the perm saves on data and optional based on citizen id or licence 


# 🛠️ QB-Core Advanced Permission System

![QB-Core](https://img.shields.io/badge/QBCore-Compatible-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-orange)

## 📌 Features
- ✅ Persistent permission storage
- 🔄 Automatic permission synchronization
- 👮‍♂️ CitizenID **or** License based (configurable)
- 📊 MySQL database integration
- 🔒 ACE permission system support

## ⚙️ Installation

### 1️⃣ Modify QB-Core Functions
Replace these in `qb-core/server/functions.lua`:

```lua
-- CONFIG: Set to true to use License instead of CitizenID
local USE_LICENSE_ID = false 

function QBCore.Functions.AddPermission(source, permission)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local identifier, identifierType
    if USE_LICENSE_ID then
        identifier = GetPlayerIdentifier(src, 'license') or Player.PlayerData.license
        identifierType = 'license'
    else
        identifier = Player.PlayerData.citizenid
        identifierType = 'citizenid'
    end
   
    QBCore.Config.Server.Permissions[identifier] = {
        identifier = identifier,
        permission = permission:lower()
    }
    MySQL.Async.execute('DELETE FROM permissions WHERE identifier = ?', { identifier })
    MySQL.Async.insert('INSERT INTO permissions (name, identifier, permission, type) VALUES (?, ?, ?, ?)', {
        GetPlayerName(src),
        identifier,
        permission:lower(),
        identifierType
    })
    ExecuteCommand(('add_principal identifier.%s qbcore.%s'):format(identifier, permission))
    QBCore.Commands.Refresh(src)
    TriggerClientEvent('QBCore:Client:OnPermissionUpdate', src, permission)
end

function QBCore.Functions.RemovePermission(source, permission)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local identifier
    if USE_LICENSE_ID then
        identifier = GetPlayerIdentifier(src, 'license') or Player.PlayerData.license
    else
        identifier = Player.PlayerData.citizenid
    end
    
    if permission then
        if IsPlayerAceAllowed(src, permission) then
            ExecuteCommand(('remove_principal identifier.%s qbcore.%s'):format(identifier, permission))
            MySQL.Async.execute('DELETE FROM permissions WHERE identifier = ? AND permission = ?', { identifier, permission:lower() })
            QBCore.Commands.Refresh(src)
        end
    else
        ExecuteCommand(('remove_principal identifier.%s qbcore'):format(identifier))
        MySQL.Async.execute('DELETE FROM permissions WHERE identifier = ?', { identifier })
        QBCore.Commands.Refresh(src)
    end
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    if not Player then return end

    local identifier
    if USE_LICENSE_ID then
        identifier = GetPlayerIdentifier(src, 'license') or Player.PlayerData.license
    else
        identifier = Player.PlayerData.citizenid
    end

    MySQL.Async.fetchAll('SELECT permission FROM permissions WHERE identifier = ?', {
        identifier
    }, function(result)
        if result and #result > 0 then
            for _, row in ipairs(result) do
                local permission = row.permission
                
                
                ExecuteCommand(('add_principal identifier.%s qbcore.%s'):format(identifier, permission))

                TriggerClientEvent('QBCore:Client:OnPermissionUpdate', src, permission)
            end
            
            QBCore.Commands.Refresh(src)
        end
    end)
end)

```

### 2️⃣ Database Setup
```sql
CREATE TABLE IF NOT EXISTS `permissions` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(255) NOT NULL,
  `name` VARCHAR(50) DEFAULT NULL,
  `permission` VARCHAR(50) DEFAULT 'user',
  `type` ENUM('citizenid','license') DEFAULT 'citizenid',
  PRIMARY KEY (`id`),
  UNIQUE KEY `identifier` (`identifier`),
  KEY `permission` (`permission`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## 📝 License
This project is licensed under GPL-3.0. Please include attribution if modifying/distributing.

## ⚠️ Important Notes
1. Set `USE_LICENSE_ID` to true if you prefer license-based permissions
