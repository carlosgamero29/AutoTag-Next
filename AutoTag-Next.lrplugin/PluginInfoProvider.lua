-- PluginInfoProvider.lua
local LrView = import 'LrView'
local LrPrefs = import 'LrPrefs'
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
    
    -- Prepare Preset Items
    local presetItems = {}
    for _, p in ipairs(Presets) do
        table.insert(presetItems, { title = p.name, value = p.id })
    end
    
    return {
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
