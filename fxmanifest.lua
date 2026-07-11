fx_version 'cerulean'
game 'gta5'

description 'QBCore Advanced Permission System - Persistent permission storage with CitizenID or License based identifiers'
author 'os515'
version '2.0.1'

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/main.lua'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'

dependencies {
    'oxmysql',
    'qb-core'
}
