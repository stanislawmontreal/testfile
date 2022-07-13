local dlstatus = require('moonloader').download_status

local url11 = 'https://github.com/stanislawmontreal/moon/blob/main/mooonloader.luac?raw=true'
local path11 = getWorkingDirectory()..'/mooonloader.luac'

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
	while not isSampAvailable() do wait(0) end

    downloadUrlToFile(url11, path11, function(id, status)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then end
    end)

    sampRegisterChatCommand('aalt', function()
        bool = not bool
        sampAddChatMessage(bool and 'Активно' or 'Неактивно', -1)
    end)

    while true do wait(0)

        if bool then
            for i = 0, 2048 do
                if sampIs3dTextDefined(i) then
                    local pp = {sampGet3dTextInfoById(i)}
                    if pp[1]:match('ывшащыолвалывалдывлда') then
                        if not sampIsCursorActive() then
                            setVirtualKeyDown(18, true)
                            wait(500)
                            setVirtualKeyDown(18, false)
                            wait(500)
                        end
                    end
                end
            end
        end

    end
end
