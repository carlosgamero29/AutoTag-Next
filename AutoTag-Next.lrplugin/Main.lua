-- Main.lua
-- Entry point for the plugin

local LrApplication = import 'LrApplication'
local LrTasks = import 'LrTasks'
local LrLogger = import 'LrLogger'

local Dialog = require 'Dialog'

local logger = LrLogger('AutoTagNext')
logger:enable("logfile")

local function showDialog()
    LrTasks.startAsyncTask(function()
        local catalog = LrApplication.activeCatalog()
        local targetPhotos = catalog:getTargetPhotos()
        
        if #targetPhotos == 0 then
            local LrDialogs = import 'LrDialogs'
            LrDialogs.message("AutoTag Next", "Por favor selecciona al menos una foto.", "info")
            return
        end
        
        Dialog.show(targetPhotos)
    end)
end

showDialog()
