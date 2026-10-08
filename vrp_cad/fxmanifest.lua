fx_version 'cerulean'
game 'gta5'

author 'Custom CAD System'
description 'vRP CAD and MDT System with ghmattimysql'
version '1.1.2'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
	'html/cad_distress.mp3',
	'html/cad_dispatch.mp3'
}

shared_scripts {
    '@vrp/lib/utils.lua'
}

dependency 'vrp'
dependency 'ghmattimysql'

server_script 'server/server.lua'
client_script 'client/client.lua'