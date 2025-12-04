-- API.lua
-- Handles communication with AI providers (Gemini, Ollama)

local LrHttp = import 'LrHttp'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local JSON = require 'JSON'
local Base64 = require 'Base64'

local API = {}

-- Helper to read file and encode to base64
local function encodeImage(imagePath)
    -- Verificar que la ruta existe
    if not imagePath or imagePath == "" then
        return nil, "Ruta de imagen vacía"
    end
    
    -- Verificar que el archivo existe
    if not LrFileUtils.exists(imagePath) then
        return nil, "El archivo no existe: " .. imagePath
    end
    
    -- Intentar abrir y leer el archivo
    local file, err = io.open(imagePath, "rb")
    if not file then 
        return nil, "No se pudo abrir el archivo: " .. (err or "error desconocido")
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content or content == "" then
        return nil, "El archivo está vacío o no se pudo leer"
    end
    
    return Base64.encode(content), nil
end

function API.analyze(imagePath, context, config)
    if config.provider == "gemini" then
        return API.callGemini(imagePath, context, config)
    elseif config.provider == "ollama" then
        return API.callOllama(imagePath, context, config)
    end
    return nil, "Proveedor desconocido"
end

function API.callGemini(imagePath, context, config)
    if not config.apiKey or config.apiKey == "" then
        return nil, "API Key de Gemini no configurada"
    end

    local base64Image, encodeErr = encodeImage(imagePath)
    if not base64Image then 
        return nil, encodeErr or "No se pudo leer la imagen" 
    end

    -- Construct the prompt using PromptBuilder
    local PromptBuilder = require 'PromptBuilder'
    local promptText = PromptBuilder.build(config, context)

    local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. config.model .. ":generateContent?key=" .. config.apiKey
    
    local body = {
        contents = {{
            parts = {
                { text = promptText },
                { inline_data = { mime_type = "image/jpeg", data = base64Image } }
            }
        }},
        generationConfig = {
            responseMimeType = "application/json"
        }
    }

    local response, headers = LrHttp.post(url, JSON.encode(body), {{ field = "Content-Type", value = "application/json" }})
    
    if not response then return nil, "Error de conexión con Gemini" end
    
    -- Intentar decodificar la respuesta JSON con protección contra errores
    local success, jsonResp = pcall(JSON.decode, response)
    
    if not success then
        return nil, "Error al decodificar respuesta de Gemini: " .. (response or "vacío")
    end
    
    -- Verificar si hay error en la respuesta JSON (formato de error de Google)
    if jsonResp.error then
        return nil, "Error de Gemini: " .. (jsonResp.error.message or "Desconocido")
    end
    
    if jsonResp and jsonResp.candidates and jsonResp.candidates[1] and jsonResp.candidates[1].content and jsonResp.candidates[1].content.parts and jsonResp.candidates[1].content.parts[1].text then
        local text = jsonResp.candidates[1].content.parts[1].text
        
        -- Intentar decodificar el JSON interno del texto generado
        local dataSuccess, data = pcall(JSON.decode, text)
        if dataSuccess then
            return data, nil
        else
            -- Limpieza agresiva de Markdown (```json ... ```)
            -- Buscar el primer '{' y el último '}'
            local firstBrace = text:find("{")
            local lastBrace = text:match("^.*()}") -- Encuentra el final, luego retrocedemos
            
            -- Implementación manual de lastIndexOf '}'
            local lastBraceIndex = nil
            local i = #text
            while i > 0 do
                if text:sub(i, i) == "}" then
                    lastBraceIndex = i
                    break
                end
                i = i - 1
            end
            
            if firstBrace and lastBraceIndex then
                local jsonCandidate = text:sub(firstBrace, lastBraceIndex)
                local dataSuccess2, data2 = pcall(JSON.decode, jsonCandidate)
                if dataSuccess2 then
                    return data2, nil
                end
            end
            
            return nil, "Gemini no devolvió un JSON válido. Texto recibido:\n" .. text
        end
    else
        return nil, "Respuesta inesperada de Gemini: " .. (response or "nil")
    end
end

function API.callOllama(imagePath, context, config)
    local base64Image, encodeErr = encodeImage(imagePath)
    if not base64Image then 
        return nil, encodeErr or "No se pudo leer la imagen" 
    end

    local promptText = config.systemPrompt .. "\n"
    if context.userContext then promptText = promptText .. "Contexto: " .. context.userContext .. "\n" end
    promptText = promptText .. "Responde en JSON: {title, description, keywords[]}"

    local body = {
        model = config.ollamaModel,
        prompt = promptText,
        images = { base64Image },
        stream = false,
        format = "json"
    }

    local response, headers = LrHttp.post(config.ollamaUrl, JSON.encode(body), {{ field = "Content-Type", value = "application/json" }})
    
    if not response then return nil, "Error de conexión con Ollama" end
    
    local success, jsonResp = pcall(JSON.decode, response)
    if not success then
        return nil, "Error al decodificar respuesta de Ollama: " .. (response or "vacío")
    end

    if jsonResp and jsonResp.response then
        local dataSuccess, data = pcall(JSON.decode, jsonResp.response)
        if dataSuccess then
            return data, nil
        else
            return nil, "Ollama no devolvió un JSON válido: " .. jsonResp.response
        end
    else
        return nil, "Error en respuesta de Ollama"
    end
end

return API
