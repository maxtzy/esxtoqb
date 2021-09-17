fx_version "adamant"

game "gta5"

description 'ESX Police Job'

version '1.3.0'

shared_script {
    '@qb-core/import.lua'
}

server_scripts {
	'config.lua',
	'server/main.lua'
}

client_scripts {
	'config.lua',
	'client/main.lua'
}


