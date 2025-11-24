-- Dialog.lua
-- Main UI for AutoTag Next

local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrBinding = import 'LrBinding'
local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrProgressScope = import 'LrProgressScope'
local LrDate = import 'LrDate'

local Data = require 'Data'
-- local Data = require 'Data' -- Duplicate removed
local API = require 'API'
local MetadataManager = require 'MetadataManager'
local Presets = require 'Presets'
local LrPrefs = import 'LrPrefs'

local Dialog = {}

-- Función para mostrar la ventana de gestión de datos
local function showDataManager()
    LrFunctionContext.callWithContext("Gestionar Datos", function(context)
        local f = LrView.osFactory()
        local managerProps = LrBinding.makePropertyTable(context)
        
        -- Cargar datos actuales
        local currentData = Data.load()
        
        -- Asegurar que tenemos datos (debugging)
        if not currentData.instituciones or #currentData.instituciones == 0 then
            currentData.instituciones = {"Municipalidad Provincial"}
        end
        if not currentData.areas or #currentData.areas == 0 then
            currentData.areas = {"Alcaldía"}
        end
        if not currentData.actividades or #currentData.actividades == 0 then
            currentData.actividades = {"Inauguración"}
        end
        if not currentData.ubicaciones or #currentData.ubicaciones == 0 then
            currentData.ubicaciones = {"Plaza de Armas"}
        end
        
        -- Crear listas editables con fallback
        local inst_text = table.concat(currentData.instituciones or {}, "\n")
        local area_text = table.concat(currentData.areas or {}, "\n")
        local act_text = table.concat(currentData.actividades or {}, "\n")
        local ubi_text = table.concat(currentData.ubicaciones or {}, "\n")
        
        -- Debug: Si todo está vacío, usar placeholder
        if inst_text == "" then inst_text = "Municipalidad Provincial\nGobierno Regional" end
        if area_text == "" then area_text = "Alcaldía\nGerencia Municipal" end
        if act_text == "" then act_text = "Inauguración\nInspección" end
        if ubi_text == "" then ubi_text = "Plaza de Armas\nPalacio Municipal" end
        
        managerProps.instituciones_text = inst_text
        managerProps.areas_text = area_text
        managerProps.actividades_text = act_text
        managerProps.ubicaciones_text = ubi_text
        
        local contents = f:column {
            spacing = f:control_spacing(),
            fill_horizontal = 1,
            
            f:static_text {
                title = "📝 Instrucciones:",
                font = "<system/bold>"
            },
            f:static_text {
                title = "• Escribe un valor por línea\n• Usa Shift+Enter para nueva línea (NO solo Enter)\n• Cuando termines, haz clic en '💾 Guardar Cambios'",
                height_in_lines = 3
            },
            
            f:separator { fill_horizontal = 1 },
            
            f:row {
                spacing = f:control_spacing(),
                fill_horizontal = 1,
                
                -- Columna 1: Instituciones y Áreas
                f:column {
                    spacing = f:control_spacing(),
                    fill_horizontal = 1,
                    
                    f:static_text { title = "Instituciones:", font = "<system/bold>" },
                    f:edit_field {
                        value = LrView.bind('instituciones_text'),
                        fill_horizontal = 1,
                        height_in_lines = 10,
                        width_in_chars = 30,
                        immediate = true
                    },
                    
                    f:static_text { title = "Áreas:", font = "<system/bold>" },
                    f:edit_field {
                        value = LrView.bind('areas_text'),
                        fill_horizontal = 1,
                        height_in_lines = 10,
                        width_in_chars = 30,
                        immediate = true
                    }
                },
                
                -- Columna 2: Actividades y Lugares
                f:column {
                    spacing = f:control_spacing(),
                    fill_horizontal = 1,
                    
                    f:static_text { title = "Actividades:", font = "<system/bold>" },
                    f:edit_field {
                        value = LrView.bind('actividades_text'),
                        fill_horizontal = 1,
                        height_in_lines = 10,
                        width_in_chars = 30,
                        immediate = true
                    },
                    
                    f:static_text { title = "Lugares:", font = "<system/bold>" },
                    f:edit_field {
                        value = LrView.bind('ubicaciones_text'),
                        fill_horizontal = 1,
                        height_in_lines = 10,
                        width_in_chars = 30,
                        immediate = true
                    }
                }
            },
            
            f:static_text {
                title = "Nota: Las líneas vacías serán eliminadas automáticamente.",
                text_color = import 'LrColor'(0.5, 0.5, 0.5)
            }
        }
        
        local result = LrDialogs.presentModalDialog {
            title = "✏️ Gestionar Datos del Plugin",
            contents = contents,
            bind_to_object = managerProps,
            actionVerb = "< hidden >",  -- Ocultar botón OK para que Enter no cierre
            cancelVerb = "Cerrar",
            otherVerb = "💾 Guardar Cambios"
        }
        
        if result == "other" then
            -- Procesar y guardar los datos
            local function parseLines(text)
                local list = {}
                for line in string.gmatch(text, "[^\r\n]+") do
                    local trimmed = line:match("^%s*(.-)%s*$")
                    if trimmed and trimmed ~= "" then
                        table.insert(list, trimmed)
                    end
                end
                return list
            end
            
            local newData = {
                instituciones = parseLines(managerProps.instituciones_text),
                areas = parseLines(managerProps.areas_text),
                actividades = parseLines(managerProps.actividades_text),
                ubicaciones = parseLines(managerProps.ubicaciones_text)
            }
            
            Data.saveAll(newData)
            LrDialogs.message("Guardado", "Los datos se han actualizado correctamente.", "info")
        end
    end)
end

function Dialog.show(photos)
    LrFunctionContext.callWithContext("AutoTag Dialog", function(context)
        local f = LrView.osFactory()
        local props = LrBinding.makePropertyTable(context)
        
        -- Load config directly from LrPrefs
        local prefs = LrPrefs.prefsForPlugin()
        
        -- Helper to get the correct prompt
        local function getPrompt()
            if prefs.useCustomPrompt and prefs.customPrompt ~= "" then
                return prefs.customPrompt
            end
            
            local presetId = prefs.promptPreset or "municipality"
            for _, p in ipairs(Presets) do
                if p.id == presetId then
                    return p.prompt
                end
            end
            
            -- Fallback to default (Municipality)
            return Presets[1].prompt
        end
        
        local config = {
            provider = prefs.provider or "gemini",
            apiKey = prefs.geminiApiKey or "", 
            model = prefs.geminiModel or "gemini-2.5-flash",
            ollamaUrl = prefs.ollamaUrl or "http://localhost:11434/api/generate",
            ollamaModel = prefs.ollamaModel or "llava",
            -- systemPrompt is now dynamic
        }
        
        local municipalityData = Data.load()

        -- Initialize props
        props.photos = photos
        props.currentIndex = 1
        props.totalPhotos = #photos
        props.currentPhoto = photos[1]
        
        -- Shared Context
        props.userContext = prefs.lastUserContext or ""
        props.institution = prefs.lastInstitution or ""
        props.area = prefs.lastArea or ""
        props.activity = prefs.lastActivity or ""
        props.location = prefs.lastLocation or ""
        
        -- Listas acumulativas (múltiples valores)
        props.institutions_list = {} -- Lista de instituciones agregadas
        props.areas_list = {}
        props.activities_list = {}
        props.locations_list = {}
        
        -- Listas dinámicas para los combos
        props.institution_items = municipalityData.instituciones
        props.area_items = municipalityData.areas
        props.activity_items = municipalityData.actividades
        props.location_items = municipalityData.ubicaciones
        
        -- Metadata
        props.title = ""
        props.description = ""
        props.keywords = ""
        
        -- UI State
        props.isAnalyzing = false
        props.statusMessage = "Listo para analizar " .. #photos .. " foto(s)."
        props.photoCounter = "1 / " .. #photos

        -- Helper to load metadata for current photo
        local function loadPhotoMetadata()
            local photo = props.currentPhoto
            if not photo then return end
            
            props.title = photo:getFormattedMetadata('title') or ""
            props.description = photo:getFormattedMetadata('caption') or ""
            props.photoCounter = props.currentIndex .. " / " .. props.totalPhotos
        end

        -- Observer for photo changes (Critical for preview update)
        props:addObserver('currentPhoto', function()
            loadPhotoMetadata()
        end)

        -- Observers for persistence
        local function savePref(key, value)
            prefs[key] = value
        end
        
        props:addObserver('userContext', function(_, _, value) savePref('lastUserContext', value) end)
        props:addObserver('institution', function(_, _, value) savePref('lastInstitution', value) end)
        props:addObserver('area', function(_, _, value) savePref('lastArea', value) end)
        props:addObserver('activity', function(_, _, value) savePref('lastActivity', value) end)
        props:addObserver('location', function(_, _, value) savePref('lastLocation', value) end)

        -- Initial load
        loadPhotoMetadata()

        -- Navigation Handlers
        local function nextPhoto()
            if props.currentIndex < props.totalPhotos then
                props.currentIndex = props.currentIndex + 1
                props.currentPhoto = props.photos[props.currentIndex] -- Trigger observer
            end
        end

        local function prevPhoto()
            if props.currentIndex > 1 then
                props.currentIndex = props.currentIndex - 1
                props.currentPhoto = props.photos[props.currentIndex] -- Trigger observer
            end
        end

        -- Analysis Logic
        local function analyzeCurrent()
            LrTasks.startAsyncTask(function()
                props.isAnalyzing = true
                props.statusMessage = "Iniciando análisis..."
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
                        institutions = props.institution and {props.institution} or {},
                        areas = props.area and {props.area} or {},
                        activities = props.activity and {props.activity} or {},
                        locations = props.location and {props.location} or {}
                    }
                }
                
                -- Actualizar progreso
                progress:setPortionComplete(0.3, 1)
                props.statusMessage = "Enviando a Gemini..."
                
                -- Set dynamic prompt
                config.systemPrompt = getPrompt()
                
                -- Llamada directa
                local result, err = API.analyze(photo:getRawMetadata('path'), contextData, config)
                
                progress:setPortionComplete(0.9, 1)
                
                if result then
                    -- Asignación directa a las propiedades enlazadas
                    -- Forzar actualización de UI
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
                        -- Usar salto de línea para mostrar como lista vertical
                        props.keywords = table.concat(cleanKeywords, "\n")
                    elseif result.keywords and type(result.keywords) == "string" then
                        local clean = result.keywords:gsub("\\u003e", ">"):gsub("u003e", ">")
                        -- Si viene como string con comas, convertir a newlines
                        props.keywords = clean:gsub(",%s*", "\n")
                    else
                        props.keywords = ""
                    end
                    
                    local endTime = LrDate.currentTime()
                    local duration = endTime - startTime
                    props.statusMessage = string.format("✓ Análisis completado en %.2f s.", duration)
                    progress:setCaption(string.format("¡Completado en %.2f s!", duration))
                else
                    local errorMsg = err or "Error desconocido"
                    props.statusMessage = "✗ Error: " .. errorMsg
                    LrDialogs.message("Fallo en Análisis", "La API devolvió error:\n" .. errorMsg, "critical")
                end
                
                progress:done()
                props.isAnalyzing = false
                
                progress:done()
                props.isAnalyzing = false
            end)
        end

        local function analyzeBatch()
            LrTasks.startAsyncTask(function()
                props.isAnalyzing = true
                local startTime = LrDate.currentTime()
                local progress = LrProgressScope({ title = "Analizando Lote AutoTag Next" })
                
                local contextData = {
                    userContext = props.userContext,
                    municipalityData = {
                        institutions = props.institutions_list,
                        areas = props.areas_list,
                        activities = props.activities_list,
                        locations = props.locations_list
                    }
                }

                local successCount = 0
                local errorCount = 0

                for i, photo in ipairs(props.photos) do
                    if progress:isCanceled() then break end
                    progress:setPortionComplete(i-1, props.totalPhotos)
                    progress:setCaption("Analizando " .. i .. " de " .. props.totalPhotos)
                    
                    -- Batch Delay
                    if i > 1 and prefs.batchDelay and prefs.batchDelay > 0 then
                        LrTasks.sleep(prefs.batchDelay / 1000)
                    end
                    
                    -- Set dynamic prompt
                    config.systemPrompt = getPrompt()
                    
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
        
        local function saveCurrent()
            LrTasks.startAsyncTask(function()
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
                    institutions = props.institutions_list,
                    areas = props.areas_list,
                    activities = props.activities_list,
                    locations = props.locations_list
                 }
                 
                 -- Usar LrTasks.pcall para permitir yielding (necesario para withWriteAccessDo)
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
                props.statusMessage = "✗ Error al guardar: " .. tostring(err)
                    LrDialogs.message("Error de Guardado", "No se pudieron guardar los metadatos:\n" .. tostring(err), "critical")
                 end
            end)
        end

        -- UI Components - Dropdowns simples (funcional)
        local function createDropdown(title, propName, category)
            return f:row {
                f:static_text { title = title, width = 120, alignment = 'right' },
                f:combo_box {
                    value = LrView.bind(propName),
                    items = LrView.bind {
                        key = category,
                        bind_to_object = props
                    },
                    width = 250,
                    immediate = true
                }
            }
        end

        local topSection = f:group_box {
            title = "Contexto del Evento (Aplica a todas las fotos)",
            fill_horizontal = 1,
            f:column {
                spacing = f:control_spacing(),
                fill_horizontal = 1,
                
                f:row {
                    f:static_text { title = "Contexto:", width = 100, alignment = 'right' },
                    f:edit_field {
                        value = LrView.bind('userContext'),
                        width_in_chars = 50,
                        placeholder = "Ej: Entrega de obras en el sector norte..."
                    },
                    f:push_button {
                        title = "✏️ Gestionar Datos",
                        action = function()
                            showDataManager()
                            -- Recargar datos después de editar
                            local newData = Data.load()
                            props.institution_items = newData.instituciones
                            props.area_items = newData.areas
                            props.activity_items = newData.actividades
                            props.location_items = newData.ubicaciones
                        end
                    }
                },
                f:row {
                    f:column {
                        spacing = f:control_spacing(),
                        createDropdown("Institución:", 'institution', 'instituciones'),
                        createDropdown("Área:", 'area', 'areas'),
                    },
                    f:column {
                        spacing = f:control_spacing(),
                        createDropdown("Actividad:", 'activity', 'actividades'),
                        createDropdown("Lugar:", 'location', 'ubicaciones'),
                    }
                }
            }
        }

        local photoSection = f:group_box {
            title = "Vista Previa",
            f:column {
                spacing = f:control_spacing(),
                
                -- Filename display to verify navigation
                f:static_text {
                    title = LrView.bind { 
                        key = 'currentPhoto', 
                        transform = function(p) 
                            if p then
                                return "Foto: " .. p:getFormattedMetadata('fileName') .. "\nRuta: " .. p:getRawMetadata('path')
                            else
                                return "Sin foto seleccionada"
                            end
                        end 
                    },
                    alignment = 'center',
                    fill_horizontal = 1,
                    height_in_lines = 2
                },
                
                f:view {
                    width = 350,
                    height = 350,
                    place = 'horizontal',
                    place_vertical = 0.5,
                    place_horizontal = 0.5,
                    
                    f:catalog_photo {
                        photo = LrView.bind('currentPhoto'),
                        width = 350,
                        height = 350,
                    }
                },
                
                f:row {
                    fill_horizontal = 1,
                    f:push_button { 
                        title = "◀ Anterior", 
                        action = prevPhoto,
                        enabled = LrView.bind { key = 'currentIndex', transform = function(value) return value > 1 end }
                    },
                    f:static_text { 
                        title = LrView.bind('photoCounter'),
                        alignment = 'center',
                        fill_horizontal = 1
                    },
                    f:push_button { 
                        title = "Siguiente ▶", 
                        action = nextPhoto,
                        enabled = LrView.bind { key = 'currentIndex', transform = function(value) return value < props.totalPhotos end }
                    },
                }
            }
        }

        local metadataSection = f:group_box {
            title = "Metadatos Generados",
            fill_horizontal = 1,
            f:column {
                spacing = f:control_spacing(),
                fill_horizontal = 1,
                
                f:static_text { title = "Título:" },
                f:edit_field { 
                    value = LrView.bind('title'), 
                    fill_horizontal = 1, 
                    height_in_lines = 2, -- Más espacio para títulos largos
                    immediate = true 
                },
                
                f:static_text { title = "Descripción:" },
                f:edit_field { 
                    value = LrView.bind('description'), 
                    fill_horizontal = 1, 
                    height_in_lines = 8, -- Mucho más espacio para descripciones detalladas
                    immediate = true 
                },
                
                f:static_text { title = "Keywords (una por línea):" },
                f:edit_field { 
                    value = LrView.bind('keywords'), 
                    fill_horizontal = 1, 
                    height_in_lines = 12, -- Mucho más espacio para ver todas las keywords
                    immediate = true 
                },
            }
        }

        local actionButtons = f:row {
            fill_horizontal = 1,
            f:push_button { 
                title = "🔍 Analizar Foto Actual", 
                action = analyzeCurrent,
                enabled = LrView.bind { key = 'isAnalyzing', transform = function(value) return not value end }
            },
            f:push_button { 
                title = "💾 Guardar Actual", 
                action = saveCurrent,
                enabled = LrView.bind { key = 'isAnalyzing', transform = function(value) return not value end }
            },
            f:push_button { 
                title = "⚡ Analizar Todo el Lote", 
                action = analyzeBatch,
                enabled = LrView.bind { key = 'isAnalyzing', transform = function(value) return not value end }
            },
        }

        local mainContent = f:column {
            bind_to_object = props, -- Enlazar todo el contenido a props
            spacing = f:control_spacing(),
            fill_horizontal = 1,
            
            topSection,
            
            f:row {
                spacing = f:control_spacing(),
                photoSection,
                metadataSection
            },
            
            f:separator { fill_horizontal = 1 },
            
            actionButtons,
            
            f:static_text { 
                title = LrView.bind('statusMessage'), 
                fill_horizontal = 1,
                text_color = import 'LrColor'(0, 0.5, 0) 
            }
        }

        LrDialogs.presentModalDialog {
            title = "AutoTag Next - Análisis con IA",
            contents = mainContent,
            cancelVerb = "Cerrar"
        }
    end)
end

return Dialog
