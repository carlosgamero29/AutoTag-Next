-- AnalysisLogic.lua
-- Analysis and batch processing logic

local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrProgressScope = import 'LrProgressScope'
local LrDate = import 'LrDate'
local LrPrefs = import 'LrPrefs'
local API = require 'API'
local MetadataManager = require 'MetadataManager'

local AnalysisLogic = {}

-- Analyze current photo
function AnalysisLogic.analyzeCurrent(props, config, getPromptFunc)
    if props.isAnalyzing then return end
    props.isAnalyzing = true
    props.statusMessage = "Analizando foto actual..."
    
    LrTasks.startAsyncTask(function()
        local startTime = LrDate.currentTime()
        
        -- Crear barra de progreso nativa de Lightroom
        local progress = LrProgressScope({ title = "AutoTag Next: Analizando foto..." })
        progress:setPortionComplete(0, 1)
        
        local photo = props.photos[props.currentIndex]
        if not photo then
            LrDialogs.message("Error", "No hay foto seleccionada", "critical")
            progress:done()
            props.isAnalyzing = false
            return
        end

        local contextData = {
            userContext = props.userContext,
            municipalityData = {
                institutions = props.selected_instituciones or {},
                areas = props.selected_areas or {},
                activities = props.selected_actividades or {},
                locations = props.selected_ubicaciones or {}
            }
        }
        
        -- Actualizar progreso
        progress:setPortionComplete(0.3, 1)
        props.statusMessage = "Enviando a Gemini..."
        
        -- Set dynamic prompt
        config.systemPrompt = getPromptFunc()
        
        -- Llamada directa
        local result, err = API.analyze(photo:getRawMetadata('path'), contextData, config)
        
        progress:setPortionComplete(0.9, 1)
        
        if result then
            -- Asignación directa a las propiedades enlazadas
            LrTasks.sleep(0.1)
            
            props.title = result.title or ""
            props.description = result.description or ""
            
            if result.keywords and type(result.keywords) == "table" then
                -- Limpiar unicode escapes (\u003e -> >)
                local cleanKeywords = {}
                for _, kw in ipairs(result.keywords) do
                    local clean = kw:gsub("\\u003e", ">"):gsub("u003e", ">")
                    table.insert(cleanKeywords, clean)
                end
                props.keywords = table.concat(cleanKeywords, "\n")
            elseif result.keywords and type(result.keywords) == "string" then
                local clean = result.keywords:gsub("\\u003e", ">"):gsub("u003e", ">")
                props.keywords = clean:gsub(",%s*", "\n")
            else
                props.keywords = ""
            end
            
            local endTime = LrDate.currentTime()
            local duration = endTime - startTime
            props.statusMessage = string.format("✓ Análisis completado en %.2f s.", duration)
            progress:setCaption(string.format("¡Completado en %.2f s!", duration))
            
            -- Log to History
            local HistoryManager = require 'HistoryManager'
            HistoryManager.log({
                filename = photo:getFormattedMetadata('fileName'),
                title = result.title,
                keywordsCount = result.keywords and #result.keywords or 0
            })
        else
            local errorMsg = err or "Error desconocido"
            props.statusMessage = "✗ Error: " .. errorMsg
            LrDialogs.message("Fallo en Análisis", "La API devolvió error:\n" .. errorMsg, "critical")
        end
        
        progress:done()
        props.isAnalyzing = false
    end)
end

-- Analyze all photos in batch
function AnalysisLogic.analyzeBatch(props, config, getPromptFunc)
    LrTasks.startAsyncTask(function()
        local prefs = LrPrefs.prefsForPlugin()
        props.isAnalyzing = true
        props.cancelBatch = false -- Reset cancel flag
        local startTime = LrDate.currentTime()
        local progress = LrProgressScope({ title = "Analizando Lote AutoTag Next" })
        
        local contextData = {
            userContext = props.userContext,
            municipalityData = {
                institutions = props.selected_instituciones or {},
                areas = props.selected_areas or {},
                activities = props.selected_actividades or {},
                locations = props.selected_ubicaciones or {}
            }
        }

        local successCount = 0
        local errorCount = 0

        for i, photo in ipairs(props.photos) do
            if progress:isCanceled() or props.cancelBatch then break end
            progress:setPortionComplete(i-1, props.totalPhotos)
            progress:setCaption("Analizando " .. i .. " de " .. props.totalPhotos)
            
            -- Batch Delay
            if i > 1 and prefs.batchDelay and prefs.batchDelay > 0 then
                LrTasks.sleep(prefs.batchDelay / 1000)
            end
            
            -- Set dynamic prompt
            config.systemPrompt = getPromptFunc()
            
            local result, err = API.analyze(photo:getRawMetadata('path'), contextData, config)
            
            if result then
                local saveOptions = {
                    saveTitle = prefs.saveTitle,
                    saveDescription = prefs.saveDescription,
                    saveKeywords = prefs.saveKeywords
                }
                MetadataManager.applyMetadata({photo}, result, contextData.municipalityData, saveOptions)
                successCount = successCount + 1
            else
                errorCount = errorCount + 1
            end
        end
        
        progress:done()
        props.isAnalyzing = false
        local endTime = LrDate.currentTime()
        local duration = endTime - startTime
        props.statusMessage = string.format("Lote completado: %d exitosas, %d errores (%.2f s)", successCount, errorCount, duration)
        LrDialogs.message("AutoTag Next", string.format("Proceso terminado.\n✓ %d fotos analizadas\n✗ %d errores", successCount, errorCount), "info")
    end)
end

-- Save current photo metadata
function AnalysisLogic.saveCurrent(props)
    LrTasks.startAsyncTask(function()
        local prefs = LrPrefs.prefsForPlugin()
        props.statusMessage = "Guardando metadatos..."
        
        local photo = props.photos[props.currentIndex]
        local metadata = {
            title = props.title,
            description = props.description,
            keywords = {}
        }
        
        -- Parse keywords string (line by line)
        if props.keywords and props.keywords ~= "" then
            for kw in string.gmatch(props.keywords, "[^\r\n]+") do
                local cleanKw = kw:match("^%s*(.-)%s*$")
                if cleanKw and cleanKw ~= "" then
                    table.insert(metadata.keywords, cleanKw)
                end
            end
        end
        
        local muniData = {
            institutions = props.selected_instituciones or {},
            areas = props.selected_areas or {},
            activities = props.selected_actividades or {},
            locations = props.selected_ubicaciones or {}
        }
        
        -- Usar LrTasks.pcall para permitir yielding
        local success, err = LrTasks.pcall(function()
            local saveOptions = {
                saveTitle = prefs.saveTitle,
                saveDescription = prefs.saveDescription,
                saveKeywords = prefs.saveKeywords
            }
            MetadataManager.applyMetadata({photo}, metadata, muniData, saveOptions)
        end)
        
        if success then
            props.statusMessage = "✓ Metadatos guardados en la foto actual."
            LrDialogs.message("Guardado", "Los metadatos se han guardado en la foto.", "info")
        else
            props.statusMessage = "✗ Error al guardar: " .. tostring(err)
            LrDialogs.message("Error", "No se pudo guardar: " .. tostring(err), "critical")
        end
    end)
end

-- Stop current batch analysis
function AnalysisLogic.stopAnalysis(props)
    props.cancelBatch = true
    props.statusMessage = "Deteniendo análisis..."
end

-- Save batch (apply current context to all photos without AI)
function AnalysisLogic.saveBatch(props)
    LrTasks.startAsyncTask(function()
        local prefs = LrPrefs.prefsForPlugin()
        props.isAnalyzing = true
        props.statusMessage = "Aplicando metadatos a todo el lote..."
        
        local progress = LrProgressScope({ title = "Guardando Lote (Sin IA)" })
        
        local contextData = {
            userContext = props.userContext,
            municipalityData = {
                institutions = props.selected_instituciones or {},
                areas = props.selected_areas or {},
                activities = props.selected_actividades or {},
                locations = props.selected_ubicaciones or {}
            }
        }
        
        local saveOptions = {
            saveTitle = false, -- Don't overwrite title/desc with empty values in this mode
            saveDescription = false,
            saveKeywords = true -- Only apply keywords (context + location)
        }
        
        local count = 0
        for i, photo in ipairs(props.photos) do
            if progress:isCanceled() then break end
            progress:setPortionComplete(i-1, props.totalPhotos)
            
            -- Apply metadata
            MetadataManager.applyMetadata({photo}, {}, contextData.municipalityData, saveOptions)
            count = count + 1
        end
        
        progress:done()
        props.isAnalyzing = false
        props.statusMessage = "✓ Se aplicaron datos a " .. count .. " fotos."
        LrDialogs.message("Guardado Lote", "Se aplicaron los datos de contexto a " .. count .. " fotos.", "info")
    end)
end

return AnalysisLogic
