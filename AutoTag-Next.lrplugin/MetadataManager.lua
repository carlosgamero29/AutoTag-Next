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
    
    -- Clave única para el caché (nombre + nombre del padre si existe)
    -- NOTA: No usar localIdentifier aquí porque falla con keywords recién creados
    local parentName = "root"
    if parent then
        -- Intentar obtener el nombre del padre de forma segura
        local s, n = pcall(function() return parent:getName() end)
        if s and n then parentName = n else parentName = tostring(parent) end
    end
    
    local cacheKey = keywordName .. "::" .. parentName
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
function MetadataManager.applyMetadata(photos, metadata, municipalityData, options)
    local catalog = LrApplication.activeCatalog()
    
    -- Default options if not provided
    options = options or { saveTitle = true, saveDescription = true, saveKeywords = true }
    
    -- Intentar escribir con un timeout de 10 segundos para evitar bloqueos
    catalog:withWriteAccessDo("AutoTag Apply", function()
        for _, photo in ipairs(photos) do
            -- 1. Basic Metadata
            if options.saveTitle and metadata.title then 
                photo:setRawMetadata('title', metadata.title) 
            end
            if options.saveDescription and metadata.description then 
                photo:setRawMetadata('caption', metadata.description) 
            end
            
            -- 2. Keywords
            local keywordsAdded = 0
            if options.saveKeywords and metadata.keywords and #metadata.keywords > 0 then
                -- Crear set de valores de contexto para evitar duplicados
                local contextValues = {}
                if municipalityData.institution then contextValues[municipalityData.institution:lower()] = true end
                if municipalityData.area then contextValues[municipalityData.area:lower()] = true end
                if municipalityData.activity then contextValues[municipalityData.activity:lower()] = true end
                if municipalityData.location then contextValues[municipalityData.location:lower()] = true end
                
                for _, kwString in ipairs(metadata.keywords) do
                    -- Limpiar espacios extra
                    kwString = kwString:match("^%s*(.-)%s*$")
                    
                    -- Verificar si es jerárquica (contiene '>')
                    if kwString:find(">") then
                        local parts = {}
                        for part in string.gmatch(kwString, "([^>]+)") do
                            table.insert(parts, part:match("^%s*(.-)%s*$"))
                        end
                        
                        -- Crear jerarquía paso a paso
                        local currentParent = nil
                        for _, partName in ipairs(parts) do
                            -- Verificar duplicados con contexto solo para el último nivel o todos?
                            -- Mejor no filtrar partes intermedias de la jerarquía
                            local kw = getKeyword(catalog, partName, currentParent)
                            if kw then
                                currentParent = kw
                            end
                        end
                        
                        -- Asignar solo la hoja (último nivel), Lightroom infiere los padres
                        if currentParent then
                            photo:addKeyword(currentParent)
                            keywordsAdded = keywordsAdded + 1
                        end
                    else
                        -- Palabra clave simple
                        if not contextValues[kwString:lower()] then
                            local kw = getKeyword(catalog, kwString, nil)
                            if kw then 
                                photo:addKeyword(kw) 
                                keywordsAdded = keywordsAdded + 1
                            end
                        end
                    end
                end
            end
            
            -- 3. Municipality Data (Directamente en la raíz, sin "AutoTag Info")
            
            if municipalityData.institution and municipalityData.institution ~= "" then
                local instParent = getKeyword(catalog, "Institución", nil)
                if instParent then
                    local k = getKeyword(catalog, municipalityData.institution, instParent)
                    if k then photo:addKeyword(k) end
                end
            end
            
            if municipalityData.area and municipalityData.area ~= "" then
                local areaParent = getKeyword(catalog, "Área", nil)
                if areaParent then
                    local k = getKeyword(catalog, municipalityData.area, areaParent)
                    if k then photo:addKeyword(k) end
                end
            end
            
            if municipalityData.activity and municipalityData.activity ~= "" then
                local actParent = getKeyword(catalog, "Actividad", nil)
                if actParent then
                    local k = getKeyword(catalog, municipalityData.activity, actParent)
                    if k then photo:addKeyword(k) end
                end
            end
            
            if municipalityData.location and municipalityData.location ~= "" then
                local locParent = getKeyword(catalog, "Lugar", nil)
                if locParent then
                    local k = getKeyword(catalog, municipalityData.location, locParent)
                    if k then photo:addKeyword(k) end
                end
            end
        end
    end, { timeout = 10 }) -- Esperar hasta 10 segundos si Lightroom está ocupado
end

return MetadataManager
