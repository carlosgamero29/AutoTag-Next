-- PromptBuilder.lua
-- Handles construction of AI prompts with context and templates

local PromptBuilder = {}

function PromptBuilder.build(config, context)
    local promptText = config.systemPrompt .. "\n\n"
    
    -- Add User Context
    if context.userContext and context.userContext ~= "" then
        promptText = promptText .. "Contexto del usuario: " .. context.userContext .. "\n"
    end
    
    -- Add Municipality/Category Data
    if context.municipalityData then
        promptText = promptText .. "Datos de contexto disponibles:\n"
        
        -- Helper to format list or single string
        local function formatValue(val)
            if type(val) == "table" then
                return table.concat(val, ", ")
            else
                return tostring(val)
            end
        end

        if context.municipalityData.institutions and #context.municipalityData.institutions > 0 then 
            promptText = promptText .. "- Institución(es): " .. formatValue(context.municipalityData.institutions) .. "\n" 
        end
        if context.municipalityData.areas and #context.municipalityData.areas > 0 then 
            promptText = promptText .. "- Área(s): " .. formatValue(context.municipalityData.areas) .. "\n" 
        end
        if context.municipalityData.activities and #context.municipalityData.activities > 0 then 
            promptText = promptText .. "- Actividad(es): " .. formatValue(context.municipalityData.activities) .. "\n" 
        end
        if context.municipalityData.locations and #context.municipalityData.locations > 0 then 
            promptText = promptText .. "- Lugar(es): " .. formatValue(context.municipalityData.locations) .. "\n"
            
            -- Add detailed location info if available
            local Data = require 'Data'
            for _, loc in ipairs(context.municipalityData.locations) do
                local details = Data.getLocationDetails(loc)
                if details then
                    local locationInfo = {}
                    if details.district and details.district ~= "" then
                        table.insert(locationInfo, "Distrito: " .. details.district)
                    end
                    if details.state and details.state ~= "" then
                        table.insert(locationInfo, "Estado/Provincia: " .. details.state)
                    end
                    if details.country and details.country ~= "" then
                        table.insert(locationInfo, "País: " .. details.country)
                    end
                    if details.gps and details.gps.latitude and details.gps.longitude then
                        table.insert(locationInfo, string.format("Coordenadas GPS: %.4f, %.4f", details.gps.latitude, details.gps.longitude))
                    end
                    
                    if #locationInfo > 0 then
                        promptText = promptText .. "  Detalles de '" .. loc .. "': " .. table.concat(locationInfo, " | ") .. "\n"
                    end
                end
            end
        end
    end
    
    -- Add Description Template Instructions if present
    if config.descriptionTemplate and config.descriptionTemplate ~= "" then
        promptText = promptText .. "\nIMPORTANTE: La descripción DEBE seguir estrictamente esta estructura:\n"
        promptText = promptText .. "\"" .. config.descriptionTemplate .. "\"\n"
        promptText = promptText .. "Reemplaza los marcadores {institucion}, {area}, {actividad}, {lugar} con la información más relevante del contexto o de la imagen.\n"
    end
    
    promptText = promptText .. "\nGenera una respuesta en formato JSON con los siguientes campos: title, description, keywords (lista de strings)."
    
    return promptText
end

return PromptBuilder
