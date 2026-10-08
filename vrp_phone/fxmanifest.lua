fx_version 'cerulean'
game 'gta5'

author 'Callum Jackson'
description 'vRP Mobile Phone Addon'
version '1.3.0'

shared_scripts {
    '@vrp/lib/utils.lua'
}

ui_page 'html/ui.html'

files {
    'html/ui.html',
    'html/style.css',
    'html/script.js'
}

client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'ghmattimysql'
}