-- HistoryManager.lua
-- Manages a local JSON log of analyzed photos

local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrDate = import 'LrDate'
local JSON = require 'JSON'

local HistoryManager = {}

function HistoryManager.getHistoryPath()
    local documents = LrPathUtils.getStandardFilePath('documents')
    local folder = LrPathUtils.child(documents, "AutoTagNext_Data")
    LrFileUtils.createAllDirectories(folder)
    return LrPathUtils.child(folder, "history.json")
end

function HistoryManager.load()
    local path = HistoryManager.getHistoryPath()
    if LrFileUtils.exists(path) then
        local file = io.open(path, "r")
        if file then
            local content = file:read("*all")
            file:close()
            if content and content ~= "" then
                local success, data = pcall(JSON.decode, content)
                if success then return data end
            end
        end
    end
    return {}
end

function HistoryManager.log(photoData)
    local history = HistoryManager.load()
    
    local entry = {
        date = LrDate.timeToUserFormat(LrDate.currentTime(), "%Y-%m-%d %H:%M:%S"),
        filename = photoData.filename or "Unknown",
        title = photoData.title or "",
        keywordsCount = photoData.keywordsCount or 0,
        status = "Success"
    }
    
    -- Add to beginning of list
    table.insert(history, 1, entry)
    
    -- Limit history size (e.g., last 100 entries)
    if #history > 100 then
        table.remove(history)
    end
    
    -- Save
    local path = HistoryManager.getHistoryPath()
    local file = io.open(path, "w")
    if file then
        file:write(JSON.stringify(history))
        file:close()
    end
end

return HistoryManager
