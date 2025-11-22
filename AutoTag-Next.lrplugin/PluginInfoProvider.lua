-- PluginInfoProvider.lua
local LrView = import 'LrView'
local LrPrefs = import 'LrPrefs'

local PluginInfoProvider = {}

function PluginInfoProvider.sectionsForTopOfDialog(f, propertyTable)
    local prefs = LrPrefs.prefsForPlugin()
    
    -- Initialize defaults ONLY if not set
    if prefs.provider == nil then prefs.provider = "gemini" end
    if prefs.geminiModel == nil then prefs.geminiModel = "gemini-2.5-flash" end
    if prefs.geminiApiKey == nil then prefs.geminiApiKey = "" end
    if prefs.ollamaUrl == nil then prefs.ollamaUrl = "http://localhost:11434/api/generate" end
    if prefs.ollamaModel == nil then prefs.ollamaModel = "llava" end
    
    return {
        {
            title = "Configuración de IA",
            
            f:row {
                f:static_text { title = "Proveedor:", width = LrView.share('label_width'), alignment = 'right' },
                f:popup_menu {
                    value = LrView.bind {
                        key = 'provider',
                        bind_to_object = prefs
                    },
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
                        value = LrView.bind {
                            key = 'geminiApiKey',
                            bind_to_object = prefs
                        },
                        width_in_chars = 40
                    }
                },
                f:row {
                    f:static_text { title = "Modelo:", width = LrView.share('label_width'), alignment = 'right' },
                    f:popup_menu {
                        value = LrView.bind {
                            key = 'geminiModel',
                            bind_to_object = prefs
                        },
                        items = {
                            { title = "gemini-2.5-flash (Recomendado - Más reciente)", value = "gemini-2.5-flash" },
                            { title = "gemini-2.5-pro (Razonamiento complejo)", value = "gemini-2.5-pro" },
                            { title = "gemini-2.0-flash (Estable - 2da gen)", value = "gemini-2.0-flash" },
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
                        value = LrView.bind {
                            key = 'ollamaUrl',
                            bind_to_object = prefs
                        },
                        width_in_chars = 40
                    }
                },
                f:row {
                    f:static_text { title = "Modelo:", width = LrView.share('label_width'), alignment = 'right' },
                    f:edit_field {
                        value = LrView.bind {
                            key = 'ollamaModel',
                            bind_to_object = prefs
                        },
                        width_in_chars = 20
                    }
                }
            }
        }
    }
end

return PluginInfoProvider
