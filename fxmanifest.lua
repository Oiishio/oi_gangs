fx_version 'adamant'
game 'gta5'
lua54 'yes'

author 'Oiishi'
description ''
version 'ą.0.0'

shared_script '@es_extended/imports.lua'
shared_script '@ox_lib/init.lua'
shared_script 'config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/utils.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua',
    'client/functions.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'esx_vehicleshop',
    'esx_society',
    'fivem-appearance'
}