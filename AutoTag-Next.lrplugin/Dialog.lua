-- Dialog.lua
-- Main UI for AutoTag Next (Refactored)

local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrBinding = import 'LrBinding'
local LrFunctionContext = import 'LrFunctionContext'
local LrPrefs = import 'LrPrefs'

-- Import modular components
local Data = require 'Data'
local Presets = require 'Presets'
local UIComponents = require 'UIComponents'
local PhotoNavigation = require 'PhotoNavigation'
local AnalysisLogic = require 'AnalysisLogic'

local Dialog = {}

function Dialog.show(photos)
    LrFunctionContext.callWithContext("AutoTag Dialog", function(context)
        local f = LrView.osFactory()
        local props = LrBinding.makePropertyTable(context)
        
        -- Load config from preferences
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
            
            return Presets[1].prompt
        end
        
        local config = {
            provider = prefs.provider or "gemini",
            apiKey = prefs.geminiApiKey or "", 
            model = prefs.geminiModel or "gemini-2.5-flash",
            ollamaUrl = prefs.ollamaUrl or "http://localhost:11434/api/generate",
            ollamaModel = prefs.ollamaModel or "llava",
        }
        
        -- Initialize props
        props.photos = photos
        props.currentIndex = 1
        props.totalPhotos = #photos
        props.currentPhoto = photos[1]
        
        local presetData = Data.getActivePreset()
        
        -- Get category names from preset
        local function getCategoryName(num, presetDefault)
            local customName = prefs['categoryName' .. num]
            if customName and customName ~= "" then
                return customName
            end
            if presetData.categoryNames and presetData.categoryNames[num] then
                return presetData.categoryNames[num]
            end
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
        
        -- Load preset data
        props.instituciones = presetData.instituciones or {}
        props.areas = presetData.areas or {}
        props.actividades = presetData.actividades or {}
        props.ubicaciones = presetData.ubicaciones or {}
        
        -- Multi-select lists
        props.selected_instituciones = {}
        props.selected_areas = {}
        props.selected_actividades = {}
        props.selected_ubicaciones = {}
        
        -- Temp values for dropdowns
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

        -- Setup observers and load initial metadata
        PhotoNavigation.setupObservers(props)
        PhotoNavigation.loadPhotoMetadata(props)

        -- UI Layout
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
                        UIComponents.createDropdown(f, props, cat1Name .. ":", 'temp_institution', 'instituciones', 'selected_instituciones'),
                        UIComponents.createDropdown(f, props, cat2Name .. ":", 'temp_area', 'areas', 'selected_areas'),
                    },
                    f:column {
                        spacing = f:control_spacing(),
                        UIComponents.createDropdown(f, props, cat3Name .. ":", 'temp_activity', 'actividades', 'selected_actividades'),
                        UIComponents.createDropdown(f, props, cat4Name .. ":", 'temp_location', 'ubicaciones', 'selected_ubicaciones'),
                    }
                }
            }
        }

        local photoSection = f:group_box {
            title = "Vista Previa",
            f:column {
                spacing = f:control_spacing(),
                
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
                        action = function() PhotoNavigation.prevPhoto(props) end,
                        enabled = LrView.bind { key = 'currentIndex', transform = function(value) return value > 1 end }
                    },
                    f:static_text { 
                        title = LrView.bind('photoCounter'),
                        alignment = 'center',
                        fill_horizontal = 1
                    },
                    f:push_button { 
                        title = "Siguiente ▶", 
                        action = function() PhotoNavigation.nextPhoto(props) end,
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
                    height_in_lines = 2,
                    immediate = true 
                },
                
                f:static_text { title = "Descripción:" },
                f:edit_field { 
                    value = LrView.bind('description'), 
                    fill_horizontal = 1, 
                    height_in_lines = 8,
                    immediate = true 
                },
                
                f:static_text { title = "Keywords (una por línea):" },
                f:edit_field { 
                    value = LrView.bind('keywords'), 
                    fill_horizontal = 1, 
                    height_in_lines = 12,
                    immediate = true 
                },
            }
        }

        local actionButtons = f:row {
            fill_horizontal = 1,
            f:push_button { 
                title = "🔍 Analizar Foto Actual", 
                action = function() AnalysisLogic.analyzeCurrent(props, config, getPrompt) end,
                enabled = LrView.bind { key = 'isAnalyzing', transform = function(value) return not value end }
            },
            f:push_button { 
                title = "💾 Guardar Actual", 
                action = function() AnalysisLogic.saveCurrent(props) end,
                enabled = LrView.bind { key = 'isAnalyzing', transform = function(value) return not value end }
            },
            f:push_button { 
                title = "⚡ Analizar Todo el Lote", 
                action = function() AnalysisLogic.analyzeBatch(props, config, getPrompt) end,
                enabled = LrView.bind { key = 'isAnalyzing', transform = function(value) return not value end }
            },
        }

        local mainContent = f:column {
            bind_to_object = props,
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

        -- Show dialog
        LrDialogs.presentModalDialog {
            title = "AutoTag Next - Análisis con IA",
            contents = mainContent,
            cancelVerb = "Cerrar"
        }
    end)
end

return Dialog
