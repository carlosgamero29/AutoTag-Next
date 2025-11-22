-- Dialog.lua
-- Main UI for AutoTag Next

local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrBinding = import 'LrBinding'
local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrProgressScope = import 'LrProgressScope'

local Data = require 'Data'
local Data = require 'Data'
-- local Settings = require 'Settings' -- Removed
local API = require 'API'
local MetadataManager = require 'MetadataManager'
local LrPrefs = import 'LrPrefs'

local Dialog = {}

function Dialog.show(photos)
    LrFunctionContext.callWithContext("AutoTag Dialog", function(context)
        local f = LrView.osFactory()
        local props = LrBinding.makePropertyTable(context)
        
        -- Load config directly from LrPrefs
        local prefs = LrPrefs.prefsForPlugin()
        local config = {
            provider = prefs.provider or "gemini",
            apiKey = prefs.geminiApiKey or "", -- Map for API
            model = prefs.geminiModel or "gemini-2.5-flash", -- Map for API
            ollamaUrl = prefs.ollamaUrl or "http://localhost:11434/api/generate",
            ollamaModel = prefs.ollamaModel or "llava",
            systemPrompt = "Eres un asistente experto en catalogación de fotografías para una municipalidad. Analiza la imagen y genera metadatos precisos."
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
                        institution = props.institution,
                        area = props.area,
                        activity = props.activity,
                        location = props.location
                    }
                }
                
                -- Actualizar progreso
                progress:setPortionComplete(0.3, 1)
                props.statusMessage = "Enviando a Gemini..."
                
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
                        props.keywords = table.concat(result.keywords, ", ")
                    elseif result.keywords and type(result.keywords) == "string" then
                        props.keywords = result.keywords
                    else
                        props.keywords = ""
                    end
                    
                    props.statusMessage = "✓ Análisis completado."
                    progress:setCaption("¡Análisis completado!")
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
                local progress = LrProgressScope({ title = "Analizando Lote AutoTag Next" })
                
                local contextData = {
                    userContext = props.userContext,
                    municipalityData = {
                        institution = props.institution,
                        area = props.area,
                        activity = props.activity,
                        location = props.location
                    }
                }

                local successCount = 0
                local errorCount = 0

                for i, photo in ipairs(props.photos) do
                    if progress:isCanceled() then break end
                    progress:setPortionComplete(i-1, props.totalPhotos)
                    progress:setCaption("Analizando " .. i .. " de " .. props.totalPhotos)
                    
                    local result, err = API.analyze(photo:getRawMetadata('path'), contextData, config)
                    
                    if result then
                        MetadataManager.applyMetadata({photo}, result, contextData.municipalityData)
                        successCount = successCount + 1
                    else
                        errorCount = errorCount + 1
                    end
                end
                
                progress:done()
                props.isAnalyzing = false
                props.statusMessage = string.format("Lote completado: %d exitosas, %d errores", successCount, errorCount)
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
                 
                 -- Parse keywords string to table
                 if props.keywords and props.keywords ~= "" then
                     for kw in string.gmatch(props.keywords, "([^,]+)") do
                         table.insert(metadata.keywords, kw:match("^%s*(.-)%s*$"))
                     end
                 end
                 
                 local muniData = {
                    institution = props.institution,
                    area = props.area,
                    activity = props.activity,
                    location = props.location
                 }
                 
                 -- Usar LrTasks.pcall para permitir yielding (necesario para withWriteAccessDo)
                 local success, err = LrTasks.pcall(function()
                    MetadataManager.applyMetadata({photo}, metadata, muniData)
                 end)
                 
                 if success then
                    props.statusMessage = "✓ Metadatos guardados en la foto actual."
                    LrDialogs.message("Guardado", "Los metadatos se han guardado en la foto.", "info")
                 else
                    props.statusMessage = "✗ Error al guardar: " .. tostring(err)
                    LrDialogs.message("Error de Guardado", "No se pudieron guardar los metadatos:\n" .. tostring(err), "critical")
                 end
            end)
        end

        -- UI Components
        local function createDropdown(title, propName, items)
            return f:row {
                f:static_text { title = title, width = 100, alignment = 'right' },
                f:popup_menu {
                    value = LrView.bind(propName),
                    items = items,
                    width = 200
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
                f:row {
                    f:column {
                        spacing = f:control_spacing(),
                        createDropdown("Institución:", 'institution', municipalityData.instituciones),
                        createDropdown("Área:", 'area', municipalityData.areas),
                    },
                    f:column {
                        spacing = f:control_spacing(),
                        createDropdown("Actividad:", 'activity', municipalityData.actividades),
                        createDropdown("Lugar:", 'location', municipalityData.ubicaciones),
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
                f:edit_field { value = LrView.bind('title'), fill_horizontal = 1, immediate = true },
                
                f:static_text { title = "Descripción:" },
                f:edit_field { value = LrView.bind('description'), fill_horizontal = 1, height_in_lines = 4, immediate = true },
                
                f:static_text { title = "Keywords (separadas por comas):" },
                f:edit_field { value = LrView.bind('keywords'), fill_horizontal = 1, height_in_lines = 2, immediate = true },
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
