# QBCore-Perms-Edits

A drop-in replacement for the default QBCore permission system that adds **persistent database storage** for player permissions.

## What This Does

This resource **overrides** the built-in `QBCore.Functions.AddPermission`, `QBCore.Functions.RemovePermission`, and `QBCore.Functions.HasPermission` functions from `qb-core` so that all permission changes are saved to the database and automatically restored when players rejoin.

## Key Features

- **Persistent Permissions** — Permissions survive server restarts
- **CitizenID or License Mode** — Choose whether permissions are tied to a character or an account
- **ACE Principal Integration** — Works with your existing `server.cfg` ACE groups
- **Drop-in Replacement** — Just start this resource after `qb-core`, no other changes needed

## Installation

### 1. Database Setup

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

### 2. Install the Resource

1. Download and place in your `resources` folder
2. **Important**: Ensure this resource starts **after** `qb-core` in your `server.cfg`:

```cfg
# Core framework MUST come first
ensure qb-core

# ... your other resources ...

# This resource must start AFTER qb-core
ensure QBCore-Perms-Edits
```

### 3. Configure

Edit `config.lua` to match your server setup:

| Option | Description |
|--------|-------------|
| `Config.UseLicenseId` | `false` = permissions tied to CitizenID (character-based), `true` = tied to License (account-based) |
| `Config.PermissionLevels` | Must match the ACE groups in your `server.cfg` |

### 4. ACE Groups (server.cfg)

Make sure your `server.cfg` has the ACE groups defined:

```cfg
# Example ACE principals
add_ace qbcore.god command allow
add_ace qbcore.admin command allow
add_ace qbcore.moderator command allow
```

## How It Works

This resource uses the `exports['qb-core']:GetCoreObject()` pattern to grab the QBCore object and then **replaces** the permission functions directly on it. Since it starts after `qb-core`, all internal calls within qb-core (and other resources) will use the new database-backed functions automatically.

### Commands

| Command | Permission | Description |
|---------|-----------|-------------|
| `/setperm [id] [permission]` | admin/god | Set a player's permission level |
| `/removeperm [id]` | admin/god | Remove all permissions from a player |

## Troubleshooting

### Permissions not saving?
- Check that `oxmysql` is running and the database table exists
- Enable `Config.Debug = true` in `config.lua` to see console logs

### Resource not overriding?
- Make sure `QBCore-Perms-Edits` starts **after** `qb-core` in `server.cfg`
- Check for errors in the server console on startup

### ACE principals not working?
- Verify your `server.cfg` has the correct `add_ace qbcore.[permission]` entries
- Restart the server after changing ACE settings (reconnecting isn't enough)
