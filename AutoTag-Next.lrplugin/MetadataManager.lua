-- MetadataManager.lua
-- Handles applying metadata to photos, including hierarchical keywords

local LrApplication = import 'LrApplication'
local LrTasks = import 'LrTasks'

local MetadataManager = {}

-- Cache para keywords creados en esta sesión
local keywordCache = {}

-- Helper to find or create a keyword hierarchy
local function getKeyword(catalog, keywordName, parent)
    if not keywordName or keywordName == "" then return nil end
    
    -- Limpiar nombre del keyword (trim)
    keywordName = keywordName:match("^%s*(.-)%s*$")
    
    -- Clave única para el caché (nombre + padre ID si existe)
    local cacheKey = keywordName .. (parent and parent.localIdentifier or "root")
    if keywordCache[cacheKey] then return keywordCache[cacheKey] end

    local keyword = nil
    -- Usar LrTasks.pcall para evitar crashes si el keyword es inválido y permitir yielding
    local success, result = LrTasks.pcall(function()
        -- El último 'true' es CRÍTICO: devuelve el keyword si ya existe
        if parent then
            return catalog:createKeyword(keywordName, {}, true, parent, true)
        else
            return catalog:createKeyword(keywordName, {}, true, nil, true)
        end
    end)
    
    if success and result then
        keywordCache[cacheKey] = result
        return result
    else
        -- Intentar buscarlo manualmente si falló la creación (fallback)
        local kw = catalog:getKeywordByPath(keywordName, parent)
        if kw then keywordCache[cacheKey] = kw end
        return kw
    end
end

-- Function to apply metadata to a list of photos
function MetadataManager.applyMetadata(photos, metadata, municipalityData)
    local catalog = LrApplication.activeCatalog()
    
    -- Intentar escribir con un timeout de 10 segundos para evitar bloqueos
    catalog:withWriteAccessDo("AutoTag Apply", function()
        for _, photo in ipairs(photos) do
            -- 1. Basic Metadata
            if metadata.title then 
                photo:setRawMetadata('title', metadata.title) 
            end
            if metadata.description then 
                photo:setRawMetadata('caption', metadata.description) 
            end
            
            -- 2. Keywords
            local keywordsAdded = 0
            if metadata.keywords and #metadata.keywords > 0 then
                for _, kwName in ipairs(metadata.keywords) do
                    local kw = getKeyword(catalog, kwName, nil)
                    if kw then 
                        photo:addKeyword(kw) 
                        keywordsAdded = keywordsAdded + 1
                    end
                end
            end
            
            -- 3. Municipality Data
            local rootKw = getKeyword(catalog, "AutoTag Info", nil)
            if rootKw then
                if municipalityData.institution and municipalityData.institution ~= "" then
                    local instParent = getKeyword(catalog, "Institución", rootKw)
                    if instParent then
                        local k = getKeyword(catalog, municipalityData.institution, instParent)
                        if k then photo:addKeyword(k) end
                    end
                end
                -- (Otros campos omitidos por brevedad, pero siguen la misma lógica)
                if municipalityData.area and municipalityData.area ~= "" then
                    local areaParent = getKeyword(catalog, "Área", rootKw)
                    if areaParent then
                        local k = getKeyword(catalog, municipalityData.area, areaParent)
                        if k then photo:addKeyword(k) end
                    end
                end
                
                if municipalityData.activity and municipalityData.activity ~= "" then
                    local actParent = getKeyword(catalog, "Actividad", rootKw)
                    if actParent then
                        local k = getKeyword(catalog, municipalityData.activity, actParent)
                        if k then photo:addKeyword(k) end
                    end
                end
                
                if municipalityData.location and municipalityData.location ~= "" then
                    local locParent = getKeyword(catalog, "Lugar", rootKw)
                    if locParent then
                        local k = getKeyword(catalog, municipalityData.location, locParent)
                        if k then photo:addKeyword(k) end
                    end
                end
            end
        end
    end, { timeout = 10 }) -- Esperar hasta 10 segundos si Lightroom está ocupado
end

return MetadataManager
