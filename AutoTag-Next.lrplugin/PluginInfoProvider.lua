-- PluginInfoProvider.lua
local LrView = import 'LrView'
local LrPrefs = import 'LrPrefs'
local LrApplication = import 'LrApplication'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrSystemInfo = import 'LrSystemInfo'
local Data = require 'Data'
local Presets = require 'Presets'

local PluginInfoProvider = {}

function PluginInfoProvider.sectionsForTopOfDialog(f, propertyTable)
    local prefs = LrPrefs.prefsForPlugin()
    
    -- Initialize defaults
    if prefs.provider == nil then prefs.provider = "gemini" end
    if prefs.geminiModel == nil then prefs.geminiModel = "gemini-2.5-flash" end
    if prefs.geminiApiKey == nil then prefs.geminiApiKey = "" end
    if prefs.ollamaUrl == nil then prefs.ollamaUrl = "http://localhost:11434/api/generate" end
    if prefs.ollamaModel == nil then prefs.ollamaModel = "llava" end
    
    -- New Defaults
    if prefs.promptPreset == nil then prefs.promptPreset = "municipality" end
    if prefs.useCustomPrompt == nil then prefs.useCustomPrompt = false end
    if prefs.customPrompt == nil then prefs.customPrompt = "" end
    
    if prefs.batchDelay == nil then prefs.batchDelay = 1000 end -- ms
    
    if prefs.saveTitle == nil then prefs.saveTitle = true end
    if prefs.saveDescription == nil then prefs.saveDescription = true end
    if prefs.saveKeywords == nil then prefs.saveKeywords = true end
    
    -- Category names (empty = use defaults)
    if prefs.categoryName1 == nil then prefs.categoryName1 = "" end
    if prefs.categoryName2 == nil then prefs.categoryName2 = "" end
    if prefs.categoryName3 == nil then prefs.categoryName3 = "" end
    if prefs.categoryName4 == nil then prefs.categoryName4 = "" end
    
    -- Initialize active preset
    if prefs.activePreset == nil then prefs.activePreset = "municipality" end
    
    -- Prepare Preset Items
    local presetItems = {}
    for _, p in ipairs(Presets) do
        table.insert(presetItems, { title = p.name, value = p.id })
    end
    
    -- Prepare Data Preset Items
    local dataPresetItems = {
        { title = "Municipalidad", value = "municipality" },
        { title = "Bodas", value = "weddings" },
        { title = "Prensa", value = "press" },
        { title = "Personal", value = "personal" }
    }
    
    return {
        {
            title = "Configuración de Metadatos y Contexto",
            
            -- Preset de Datos
            f:group_box {
                title = "Preset de Datos",
                
                f:row {
                    f:static_text { 
                        title = "Preset Activo:", 
                        width = LrView.share('label_width'), 
                        alignment = 'right' 
                    },
                    f:popup_menu {
                        value = LrView.bind { 
                            key = 'activePreset', 
                            bind_to_object = prefs,
                            transform = function(value, fromModel)
                                if fromModel then
                                    if value then
                                        Data.setActivePreset(value)
                                    end
                                    return value
                                else
                                    return value
                                end
                            end
                        },
                        items = dataPresetItems,
                        width = 200
                    }
                },
                
                f:static_text {
                    title = "Cada preset incluye listas predefinidas y nombres de categorías apropiados.",
                    font = "<system/small>",
                    text_color = import 'LrColor'(0.5, 0.5, 0.5)
                }
            },
            
            f:separator { fill_horizontal = 1 },
            
            -- Personalización de Categorías
            f:group_box {
                title = "Personalización de Categorías",
                
                f:static_text {
                    title = "Sobrescribe los nombres de categorías del preset activo (opcional):",
                    font = "<system/small>"
                },
                
                f:row {
                    f:static_text { title = "Categoría 1:", width = LrView.share('label_width'), alignment = 'right' },
                    f:edit_field {
                        value = LrView.bind { key = 'categoryName1', bind_to_object = prefs },
                        width_in_chars = 20,
                        placeholder = "Usar nombre del preset"
                    }
                },
                
                f:row {
                    f:static_text { title = "Categoría 2:", width = LrView.share('label_width'), alignment = 'right' },
                    f:edit_field {
                        value = LrView.bind { key = 'categoryName2', bind_to_object = prefs },
                        width_in_chars = 20,
                        placeholder = "Usar nombre del preset"
                    }
                },
                
                f:row {
                    f:static_text { title = "Categoría 3:", width = LrView.share('label_width'), alignment = 'right' },
                    f:edit_field {
                        value = LrView.bind { key = 'categoryName3', bind_to_object = prefs },
                        width_in_chars = 20,
                        placeholder = "Usar nombre del preset"
                    }
                },
                
                f:row {
                    f:static_text { title = "Categoría 4:", width = LrView.share('label_width'), alignment = 'right' },
                    f:edit_field {
                        value = LrView.bind { key = 'categoryName4', bind_to_object = prefs },
                        width_in_chars = 20,
                        placeholder = "Usar nombre del preset"
                    }
                }
            },
            
            f:separator { fill_horizontal = 1 },
            
            -- Ubicación de datos
            f:group_box {
                title = "Almacenamiento",
                
                f:row {
                    f:static_text { 
                        title = "Archivo de datos:", 
                        width = LrView.share('label_width'), 
                        alignment = 'right' 
                    },
                    f:edit_field { 
                        value = "Documentos/AutoTagNext_Data/user_data.json",
                        width = 300,
                        enabled = false
                    }
                }
            }
        },
        
        {
            title = "Configuración de IA",
            
            f:row {
                f:static_text { title = "Proveedor:", width = LrView.share('label_width'), alignment = 'right' },
                f:popup_menu {
                    value = LrView.bind { key = 'provider', bind_to_object = prefs },
                    items = {
                        { title = "Google Gemini", value = "gemini" },
                        { title = "Ollama (Local)", value = "ollama" }
                    },
                    width = 200
                }
            },
            
            f:group_box {
                title = "Google Gemini",
                f:row {
                    f:static_text { title = "API Key:", width = LrView.share('label_width'), alignment = 'right' },
                    f:password_field {
                        value = LrView.bind { key = 'geminiApiKey', bind_to_object = prefs },
                        width_in_chars = 40
                    }
                },
                f:row {
                    f:static_text { title = "Modelo:", width = LrView.share('label_width'), alignment = 'right' },
                    f:popup_menu {
                        value = LrView.bind { key = 'geminiModel', bind_to_object = prefs },
                        items = {
                            { title = "gemini-2.5-flash (Recomendado)", value = "gemini-2.5-flash" },
                            { title = "gemini-2.5-pro (Mayor precisión)", value = "gemini-2.5-pro" },
                            { title = "gemini-2.0-flash (Estable)", value = "gemini-2.0-flash" },
                            { title = "gemini-2.0-flash-exp (Experimental)", value = "gemini-2.0-flash-exp" }
                        },
                        width = 320
                    }
                }
            },
            
            f:group_box {
                title = "Ollama (Local)",
                f:row {
                    f:static_text { title = "URL:", width = LrView.share('label_width'), alignment = 'right' },
                    f:edit_field {
                        value = LrView.bind { key = 'ollamaUrl', bind_to_object = prefs },
                        width_in_chars = 40
                    }
                },
                f:row {
                    f:static_text { title = "Modelo:", width = LrView.share('label_width'), alignment = 'right' },
                    f:edit_field {
                        value = LrView.bind { key = 'ollamaModel', bind_to_object = prefs },
                        width_in_chars = 20
                    }
                }
            }
        },
        
        {
            title = "Personalización de Prompt",
            
            f:row {
                f:static_text { title = "Preset de Estilo:", width = LrView.share('label_width'), alignment = 'right' },
                f:popup_menu {
                    value = LrView.bind { key = 'promptPreset', bind_to_object = prefs },
                    items = presetItems,
                    width = 300,
                    enabled = LrView.bind { key = 'useCustomPrompt', bind_to_object = prefs, transform = function(val) return not val end }
                }
            },
            
            f:row {
                f:static_text { title = "", width = LrView.share('label_width') },
                f:checkbox {
                    title = "Usar Prompt Personalizado",
                    value = LrView.bind { key = 'useCustomPrompt', bind_to_object = prefs }
                }
            },
            
            f:row {
                f:static_text { title = "Prompt Personalizado:", width = LrView.share('label_width'), alignment = 'right' },
                f:edit_field {
                    value = LrView.bind { key = 'customPrompt', bind_to_object = prefs },
                    width = 400,
                    height_in_lines = 6,
                    enabled = LrView.bind { key = 'useCustomPrompt', bind_to_object = prefs }
                }
            }
        },
        
        {
            title = "Procesamiento por Lotes",
            
            f:row {
                f:static_text { title = "Demora entre fotos (ms):", width = LrView.share('label_width'), alignment = 'right' },
                f:edit_field {
                    value = LrView.bind { key = 'batchDelay', bind_to_object = prefs },
                    width_in_chars = 10,
                    min = 0,
                    max = 10000,
                    precision = 0
                },
                f:static_text { title = "(Recomendado: 1000ms para evitar límites de API)" }
            }
        },
        
        {
            title = "Control de Metadatos",
            
            f:row {
                f:static_text { title = "Guardar:", width = LrView.share('label_width'), alignment = 'right' },
                f:checkbox { title = "Título", value = LrView.bind { key = 'saveTitle', bind_to_object = prefs } },
                f:checkbox { title = "Descripción", value = LrView.bind { key = 'saveDescription', bind_to_object = prefs } },
                f:checkbox { title = "Palabras Clave", value = LrView.bind { key = 'saveKeywords', bind_to_object = prefs } }
            }
        }
    }
end

return PluginInfoProvider
