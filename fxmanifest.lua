fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'smdx-bossmenu'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@smdx-core/shared/locale.lua',
    'locales/en.lua', -- preferred language
    'config.lua',
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

server_exports {
    'AddMoney',
    'RemoveMoney',
    'GetAccount',
}

dependencies {
    'smdx-core',
    'ox_lib',
}

lua54 'yes'
