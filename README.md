# QBCore-Perms-Edits

Advanced Permission System for QBCore Framework - Persistent database-backed permissions with CitizenID or License-based identifiers.

![Version](https://img.shields.io/badge/version-2.0.0-blue)
![QBCore](https://img.shields.io/badge/QBCore-Compatible-green)
![License](https://img.shields.io/badge/license-GPL--3.0-orange)

---

## Features

- **Persistent Permissions** - Permissions survive server restarts via MySQL storage
- **Dual Identifier Support** - Use CitizenID (character-based) or License (account-based)
- **Auto-Sync on Join** - Database permissions are automatically applied when players connect
- **Memory Cache** - Prevents double-loading and improves performance
- **Debug Logging** - Optional verbose logging for troubleshooting
- **Admin Commands** - Built-in `/setperm` and `/removeperm` commands
- **Error Handling** - pcall-wrapped ACE commands with nil checks throughout
- **Clean Architecture** - Separated config, database, and logic layers

---

## Installation

### 1. Install as Standalone Resource (Recommended)

This is the **easiest** method - just drop it in and it overrides the built-in functions.

```
ensure oxmysql   -- must be started before this resource
ensure qb-core
ensure QBCore-Perms-Edits   -- add this after qb-core
```

Copy the `QBCore-Perms-Edits` folder to your `resources/[qb]/` directory.

### 2. Configure

Edit `config.lua`:

```lua
Config.UseLicenseId = false   -- true = license-based, false = citizenid-based
Config.Debug = false          -- true = verbose console logging
```

### 3. Database Setup

Run this SQL to create the permissions table:

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

### 4. Alternative: Manual Integration into qb-core

If you prefer to keep everything in `qb-core`:

1. Copy contents of `server/database.lua` into `qb-core/server/functions.lua`
2. Copy contents of `server/main.lua` into `qb-core/server/functions.lua`
3. Copy `config.lua` contents into `qb-core/shared/config.lua`
4. Ensure `oxmysql` is properly configured in `fxmanifest.lua`

---

## Admin Commands

| Command | Description | Permission Required |
|---------|-------------|---------------------|
| `/setperm [id] [permission]` | Set a player's permission level | admin, god |
| `/removeperm [id]` | Remove all permissions from a player | admin, god |

### Examples:
```
/setperm 5 admin     -- Give player ID 5 admin permissions
/removeperm 5        -- Remove all permissions from player ID 5
```

---

## How It Works

### Permission Flow

```
Player Joins
    |
    v
QBCore:Server:PlayerLoaded fires
    |
    v
Fetch permissions from DB (by citizenid/license)
    |
    v
Apply ACE principals (add_principal identifier.xxx qbcore.admin)
    |
    v
Refresh commands (player can now use admin commands)
    |
    v
Client receives OnPermissionUpdate event
```

### Data Flow (Granting Permission)

```
/setperm 5 admin
    |
    v
AddPermission(5, "admin")
    |
    v
Save to DB (DELETE old + INSERT new)
    |
    v
Apply ACE principal in memory
    |
    v
Commands.Refresh(5)  -- player can use admin commands
```

---

## ACE Configuration

Make sure your `server.cfg` has the appropriate ACE groups:

```cfg
# Permission groups
add_ace group.admin command.setperm allow
add_ace group.admin command.removeperm allow
add_ace group.god command.setperm allow
add_ace group.god command.removeperm allow
```

---

## Troubleshooting

### Permissions not applying on join?
- Enable `Config.Debug = true` and check server console
- Verify `QBCore:Server:PlayerLoaded` event fires (check qb-core events)
- Ensure `oxmysql` is properly connected and the `permissions` table exists
- Check that `USE_LICENSE_ID` matches how permissions were originally saved

### ACE principal errors?
- Verify your `server.cfg` has `qbcore.admin`, `qbcore.god`, etc. groups defined
- Check that `add_principal` commands use valid identifiers

### Database errors?
- Ensure `oxmysql` resource is started and configured
- Verify MySQL connection string in `server.cfg`
- Check that the `permissions` table was created successfully

---

## Changelog

### v2.0.0
- Restructured into proper resource with fxmanifest.lua
- Merged PR #1: Added PlayerLoaded event handler for permission sync
- Fixed critical bug: nil check now happens BEFORE using Player.PlayerData
- Added memory cache to prevent double-loading permissions
- Added database abstraction layer (server/database.lua)
- Added pcall error handling for ACE commands
- Added debug logging system
- Added `/setperm` and `/removeperm` admin commands
- Added input validation (source checks, nil checks, permission sanitization)
- Added playerDropped cleanup handler

### v1.0.0
- Initial release - README-only documentation

---

## License

GPL-3.0 - Include attribution if modifying or distributing.
