Config = {}

-- Permission identifier mode
-- true  = Use license identifier (Steam-independent, persists across accounts)
-- false = Use CitizenID (character-based, recommended for RP servers)
Config.UseLicenseId = false

-- Permission levels available in your server
-- These should match the ACE groups defined in your server.cfg
Config.PermissionLevels = {
    'user',         -- Default
    'admin',        -- Moderator
    'god',          -- Full admin
    'moderator',    -- Support staff
    'supporter'     -- VIP/Donator
}

-- Enable debug logging (prints to server console)
Config.Debug = false
