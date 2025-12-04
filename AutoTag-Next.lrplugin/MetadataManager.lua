-- MetadataManager.lua
-- Handles applying metadata to photos, including hierarchical keywords

local LrApplication = import 'LrApplication'
local LrTasks = import 'LrTasks'
local Data = require 'Data'

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
                if municipalityData.institutions then
                    for _, inst in ipairs(municipalityData.institutions) do
                        if inst then contextValues[inst:lower()] = true end
                    end
                end
                if municipalityData.areas then
                    for _, area in ipairs(municipalityData.areas) do
                        if area then contextValues[area:lower()] = true end
                    end
                end
                if municipalityData.activities then
                    for _, act in ipairs(municipalityData.activities) do
                        if act then contextValues[act:lower()] = true end
                    end
                end
                if municipalityData.locations then
                    for _, loc in ipairs(municipalityData.locations) do
                        if loc then contextValues[loc:lower()] = true end
                    end
                end
                
                for _, kwString in ipairs(metadata.keywords) do
                    -- Limpiar unicode escapes (\u003e -> >) y espacios extra
                    kwString = kwString:gsub("\\u003e", ">"):gsub("u003e", ">")
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
            
            -- 3. Municipality Data (Múltiples valores soportados)
            
            if municipalityData.institutions and #municipalityData.institutions > 0 then
                local instParent = getKeyword(catalog, "Institución", nil)
                if instParent then
                    for _, inst in ipairs(municipalityData.institutions) do
                        if inst and inst ~= "" then
                            local k = getKeyword(catalog, inst, instParent)
                            if k then photo:addKeyword(k) end
                        end
                    end
                end
            end
            
            if municipalityData.areas and #municipalityData.areas > 0 then
                local areaParent = getKeyword(catalog, "Área", nil)
                if areaParent then
                    for _, area in ipairs(municipalityData.areas) do
                        if area and area ~= "" then
                            local k = getKeyword(catalog, area, areaParent)
                            if k then photo:addKeyword(k) end
                        end
                    end
                end
            end
            
            if municipalityData.activities and #municipalityData.activities > 0 then
                local actParent = getKeyword(catalog, "Actividad", nil)
                if actParent then
                    for _, act in ipairs(municipalityData.activities) do
                        if act and act ~= "" then
                            local k = getKeyword(catalog, act, actParent)
                            if k then photo:addKeyword(k) end
                        end
                    end
                end
            end
            
            if municipalityData.locations and #municipalityData.locations > 0 then
                local locParent = getKeyword(catalog, "Lugar", nil)
                if locParent then
                    for _, loc in ipairs(municipalityData.locations) do
                        if loc and loc ~= "" then
                            local k = getKeyword(catalog, loc, locParent)
                            if k then photo:addKeyword(k) end
                            
                            -- Check for extended location details (District, State, Country, GPS)
                            local details = Data.getLocationDetails(loc)
                            if details then
                                -- Apply GPS
                                if details.gps and details.gps.latitude and details.gps.longitude then
                                    photo:setRawMetadata('gps', {
                                        latitude = details.gps.latitude,
                                        longitude = details.gps.longitude
                                    })
                                end
                                
                                -- Apply Hierarchy: Lugar > Distrito > [Nombre]
                                if details.district and details.district ~= "" then
                                    local distParent = getKeyword(catalog, "Distrito", locParent)
                                    if distParent then
                                        local distKw = getKeyword(catalog, details.district, distParent)
                                        if distKw then photo:addKeyword(distKw) end
                                    end
                                end
                                
                                -- Apply Hierarchy: Lugar > Estado > [Nombre]
                                if details.state and details.state ~= "" then
                                    local stateParent = getKeyword(catalog, "Estado", locParent)
                                    if stateParent then
                                        local stateKw = getKeyword(catalog, details.state, stateParent)
                                        if stateKw then photo:addKeyword(stateKw) end
                                    end
                                end
                                
                                -- Apply Hierarchy: Lugar > País > [Nombre]
                                if details.country and details.country ~= "" then
                                    local countryParent = getKeyword(catalog, "País", locParent)
                                    if countryParent then
                                        local countryKw = getKeyword(catalog, details.country, countryParent)
                                        if countryKw then photo:addKeyword(countryKw) end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end, { timeout = 10 }) -- Esperar hasta 10 segundos si Lightroom está ocupado
end

return MetadataManager
