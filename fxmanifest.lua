fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'Cortex ATM Robbery'
author 'GSDMODS/CORTEX'
description 'Rob Cortex Banking ATMs by hand: pry the service door, back out the screws, read and bridge the wiring, pull the cassette'
version '1.0.0'

shared_scripts {
    '@cortex-lib/init.lua',
    'config.lua',
    'shared/locale.lua',
    'shared/validate.lua',
    'shared/machines.lua',
    'shared/rig_bay.lua',
    'shared/rig_tools.lua',
    'shared/wiring.lua',
}

server_scripts {
    'server/placements.lua',
    'server/alert.lua',
    'server/rewards.lua',
    'server/machines.lua',
    'server/main.lua',
    'server/admin.lua',
}

client_scripts {
    '@cortex-lib/presentation-client.lua',
    'client/state.lua',
    'client/math.lua',
    'client/fx.lua',
    'client/world.lua',
    'client/camera.lua',
    'client/pointer.lua',
    'client/nui.lua',
    'client/tools.lua',
    'client/stages/pry.lua',
    'client/stages/screws.lua',
    'client/stages/wires.lua',
    'client/stages/cassette.lua',
    'client/session.lua',
    'client/main.lua',
    'client/settings.lua',
}

ui_page 'web/ui/dist/index.html'

files {
    'web/ui/dist/index.html',
    'web/ui/dist/assets/*',
    'web/lcd/index.html',
    'locales/*.json',
    'stream/**/*.ytyp',
}

data_file 'DLC_ITYP_REQUEST' 'stream/bay/cx_atmrob_bay.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/tools/cx_atmrob_tools.ytyp'

dependencies { 'cortex-lib', 'cortex-banking', 'cortex-banking-assets', 'ox_inventory', '/onesync' }

escrow_ignore {
    'fxmanifest.lua',
    'config.lua',
    'locales/*.json',
    'install/*',
}
