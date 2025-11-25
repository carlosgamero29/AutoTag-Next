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

-- Función para editar una categoría individual
local function editCategory(categoryName, categoryKey)
    LrFunctionContext.callWithContext("Editar " .. categoryName, function(context)
        local f = LrView.osFactory()
        local editProps = LrBinding.makePropertyTable(context)
        
        -- Cargar datos actuales
        local currentData = Data.load()
        local items = currentData[categoryKey] or {}
        
        -- Convertir array a texto (una línea por item)
        editProps.itemsText = table.concat(items, "\n")
        
        local result = LrDialogs.presentModalDialog {
            title = "Editar " .. categoryName,
            contents = f:column {
                spacing = f:control_spacing(),
                bind_to_object = editProps,
                
                f:static_text {
                    title = "Edita la lista (una por línea):",
                    font = "<system/bold>"
                },
                
                f:edit_field {
                    value = LrView.bind('itemsText'),
                    height_in_lines = 15,
                    width_in_chars = 40,
                    immediate = true
                },
                
                f:static_text {
                    title = "Tip: Escribe cada elemento en una línea nueva.",
                    font = "<system/small>"
                }
            },
            actionVerb = "Guardar",
            cancelVerb = "Cancelar"
        }
        
        if result == "ok" then
            -- Convertir texto a array
            local newItems = {}
            for line in editProps.itemsText:gmatch("[^\r\n]+") do
                local trimmed = line:match("^%s*(.-)%s*$") -- Trim whitespace
                if trimmed ~= "" then
                    table.insert(newItems, trimmed)
                end
            end
            
            -- Guardar
            currentData[categoryKey] = newItems
            Data.saveAll(currentData)
            
            return true -- Indica que se guardó
        end
        
        return false
    end)
end

-- Función para mostrar el menú de gestión de datos
local function showDataManager()
    -- Mostrar menú de opciones directamente
    local selectedOption = LrDialogs.presentChoiceDialog {
        title = "Gestionar Datos",
        message = "Selecciona qué lista deseas editar:",
        choices = {
            { title = "📋 Instituciones", value = "instituciones" },
            { title = "🏢 Áreas", value = "areas" },
            { title = "🎯 Actividades", value = "actividades" },
            { title = "📍 Lugares", value = "ubicaciones" },
            { title = "🔄 Restaurar Datos de Fábrica", value = "restore" }
        }
    }
    
    if not selectedOption then return end -- Usuario canceló
    
    if selectedOption == "restore" then
        if LrDialogs.confirm("¿Restaurar Datos?", "Esto borrará tus listas personalizadas y restaurará los valores originales. ¿Estás seguro?", "Sí, Restaurar", "Cancelar") == "ok" then
            local path = Data.getUserDataPath()
            import 'LrFileUtils'.delete(path)
            LrDialogs.message("Restaurado", "Los datos han sido restaurados a los valores de fábrica.", "info")
        end
    elseif selectedOption == "instituciones" then
        editCategory("Instituciones", "instituciones")
    elseif selectedOption == "areas" then
        editCategory("Áreas", "areas")
    elseif selectedOption == "actividades" then
        editCategory("Actividades", "actividades")
    elseif selectedOption == "ubicaciones" then
        editCategory("Lugares", "ubicaciones")
    end
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
        
        -- Initialize props
        props.photos = photos
        props.currentIndex = 1
        props.totalPhotos = #photos
        props.currentPhoto = photos[1] -- Inicializar con la primera foto
        
        local prefs = LrPrefs.prefsForPlugin()
        local presetData = Data.getActivePreset() -- Cargar preset activo
        
        -- Obtener nombres de categorías del preset (con fallback a personalizados o defaults)
        local function getCategoryName(num, presetDefault)
            -- Primero intentar usar el nombre personalizado del usuario
            local customName = prefs['categoryName' .. num]
            if customName and customName ~= "" then
                return customName
            end
            -- Si no hay personalizado, usar el del preset
            if presetData.categoryNames and presetData.categoryNames[num] then
                return presetData.categoryNames[num]
            end
            -- Fallback final
            return presetDefault
        end
        
        local cat1Name = getCategoryName(1, "Institución")
        local cat2Name = getCategoryName(2, "Área")
        local cat3Name = getCategoryName(3, "Actividad")
        local cat4Name = getCategoryName(4, "Lugar")
        
        props.userContext = prefs.lastUserContext or ""
        props.institution = prefs.lastInstitution or ""
        props.area = prefs.lastArea or ""
        props.activity = prefs.lastActivity or ""
        props.location = prefs.lastLocation or ""
        
        -- Cargar datos del preset activo
        props.instituciones = presetData.instituciones or {}
        props.areas = presetData.areas or {}
        props.actividades = presetData.actividades or {}
        props.ubicaciones = presetData.ubicaciones or {}
        
        -- Listas de seleccionados (múltiples valores)
        props.selected_instituciones = {}
        props.selected_areas = {}
        props.selected_actividades = {}
        props.selected_ubicaciones = {}
        
        -- Valores actuales en los dropdowns (para agregar)
        props.temp_institution = ""
        props.temp_area = ""
        props.temp_activity = ""
        props.temp_location = ""
        
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
            
            -- Cargar keywords existentes
            local existingKeywords = photo:getFormattedMetadata('keywordTags')
            if existingKeywords then
                props.keywords = existingKeywords
            else
                props.keywords = ""
            end
            
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

        -- UI Components - Dropdown con lista acumulativa para múltiples valores
        local function createDropdown(title, tempPropName, category, selectedListProp)
            return f:column {
                spacing = f:control_spacing(),
                fill_horizontal = 1,
                
                -- Fila superior: Label + Dropdown + Botones
                f:row {
                    f:static_text { title = title, width = 120, alignment = 'right' },
                    f:combo_box {
                        value = LrView.bind(tempPropName),
                        items = LrView.bind {
                            key = category,
                            bind_to_object = props
                        },
                        width = 180,
                        immediate = true
                    },
                    f:push_button {
                        title = "Agregar",
                        width = 70,
                        enabled = LrView.bind {
                            key = tempPropName,
                            transform = function(val) return val ~= nil and val ~= "" end
                        },
                        action = function()
                            local value = props[tempPropName]
                            if value and value ~= "" then
                                local list = props[selectedListProp] or {}
                                
                                -- Verificar si ya está en la lista
                                local exists = false
                                for _, v in ipairs(list) do
                                    if v == value then
                                        exists = true
                                        break
                                    end
                                end
                                
                                if not exists then
                                    local newList = {}
                                    for _, v in ipairs(list) do table.insert(newList, v) end
                                    table.insert(newList, value)
                                    props[selectedListProp] = newList
                                end
                            end
                        end
                    },
                    f:push_button {
                        title = "➕",
                        width = 30,
                        tooltip = "Agregar nuevo elemento a la lista maestra",
                        action = function()
                            LrFunctionContext.callWithContext("Agregar", function(context)
                                local addProps = LrBinding.makePropertyTable(context)
                                addProps.newValue = ""
                                
                                local result = LrDialogs.presentModalDialog {
                                    title = "Agregar a " .. title,
                                    contents = f:column {
                                        spacing = f:control_spacing(),
                                        bind_to_object = addProps,
                                        
                                        f:static_text { title = "Nuevo valor:" },
                                        f:edit_field {
                                            value = LrView.bind('newValue'),
                                            width_in_chars = 30,
                                            immediate = true
                                        }
                                    },
                                    actionVerb = "Agregar",
                                    cancelVerb = "Cancelar"
                                }
                                
                                if result == "ok" and addProps.newValue ~= "" then
                                    local currentData = Data.load()
                                    local list = currentData[category] or {}
                                    
                                    local exists = false
                                    for _, v in ipairs(list) do
                                        if v == addProps.newValue then
                                            exists = true
                                            break
                                        end
                                    end
                                    
                                    if not exists then
                                        table.insert(list, addProps.newValue)
                                        currentData[category] = list
                                        Data.saveAll(currentData)
                                        props[category] = list
                                        props[tempPropName] = addProps.newValue
                                        LrDialogs.message("Agregado", "'" .. addProps.newValue .. "' ha sido agregado.", "info")
                                    else
                                        LrDialogs.message("Duplicado", "'" .. addProps.newValue .. "' ya existe en la lista.", "warning")
                                    end
                                end
                            end)
                        end
                    }
                },
                
                -- Lista de seleccionados (simplificada)
                f:row {
                    f:static_text { title = "", width = 120 }, -- Spacer
                    f:column {
                        spacing = 3,
                        fill_horizontal = 1,
                        
                        -- Mostrar seleccionados como texto
                        f:static_text {
                            title = LrView.bind {
                                key = selectedListProp,
                                transform = function(list)
                                    if not list or #list == 0 then
                                        return "Seleccionados: (ninguno)"
                                    else
                                        return "Seleccionados: " .. table.concat(list, ", ")
                                    end
                                end
                            },
                            font = "<system/small>",
                            text_color = import 'LrColor'(0.2, 0.5, 1.0),
                            width = 300,
                            wraps = true
                        },
                        
                        -- Botón para limpiar todos
                        f:push_button {
                            title = "Limpiar todos",
                            width = 100,
                            enabled = LrView.bind {
                                key = selectedListProp,
                                transform = function(list) return list and #list > 0 end
                            },
                            action = function()
                                props[selectedListProp] = {}
                            end
                        }
                    }
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
                    }
                },
                
                f:separator { fill_horizontal = 1 },
                
                f:row {
                    f:column {
                        spacing = f:control_spacing(),
                        createDropdown(cat1Name .. ":", 'temp_institution', 'instituciones', 'selected_instituciones'),
                        createDropdown(cat2Name .. ":", 'temp_area', 'areas', 'selected_areas'),
                    },
                    f:column {
                        spacing = f:control_spacing(),
                        createDropdown(cat3Name .. ":", 'temp_activity', 'actividades', 'selected_actividades'),
                        createDropdown(cat4Name .. ":", 'temp_location', 'ubicaciones', 'selected_ubicaciones'),
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
