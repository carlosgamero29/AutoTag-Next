-- UIComponents.lua
-- Reusable UI components for AutoTag Next

local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrBinding = import 'LrBinding'
local LrFunctionContext = import 'LrFunctionContext'
local Data = require 'Data'

local UIComponents = {}

-- Función para editar una categoría individual
function UIComponents.editCategory(categoryName, categoryKey)
    LrFunctionContext.callWithContext("Editar " .. categoryName, function(context)
        local f = LrView.osFactory()
        local editProps = LrBinding.makePropertyTable(context)
        
        -- Cargar datos actuales del preset activo
        local allData = Data.load()
        local activeId = allData.activePreset or "municipality"
        local preset = allData.presets[activeId]
        local items = preset[categoryKey] or {}
        
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
            
            -- Guardar en el preset activo
            preset[categoryKey] = newItems
            Data.saveAll(allData)
            
            return true
        end
        
        return false
    end)
end

-- Función para mostrar el menú de gestión de datos
function UIComponents.showDataManager()
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
    
    if not selectedOption then return end
    
    if selectedOption == "restore" then
        if LrDialogs.confirm("¿Restaurar Datos?", "Esto borrará tus listas personalizadas y restaurará los valores originales. ¿Estás seguro?", "Sí, Restaurar", "Cancelar") == "ok" then
            local path = Data.getUserDataPath()
            import 'LrFileUtils'.delete(path)
            LrDialogs.message("Restaurado", "Los datos han sido restaurados a los valores de fábrica.", "info")
        end
    elseif selectedOption == "instituciones" then
        UIComponents.editCategory("Instituciones", "instituciones")
    elseif selectedOption == "areas" then
        UIComponents.editCategory("Áreas", "areas")
    elseif selectedOption == "actividades" then
        UIComponents.editCategory("Actividades", "actividades")
    elseif selectedOption == "ubicaciones" then
        UIComponents.editCategory("Lugares", "ubicaciones")
    end
end

-- Crear dropdown con selección múltiple y lista acumulativa
function UIComponents.createDropdown(f, props, title, tempPropName, category, selectedListProp)
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
                            local success = Data.addItem(category, addProps.newValue)
                            if success then
                                -- Recargar datos del preset activo
                                local presetData = Data.getActivePreset()
                                props[category] = presetData[category] or {}
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

return UIComponents
