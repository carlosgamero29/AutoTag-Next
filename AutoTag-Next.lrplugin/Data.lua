-- Data.lua
-- Stores the municipality structure (Institutions, Areas, Activities)
-- Now supports saving user additions to a JSON file

local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local JSON = require 'JSON'

local Data = {}

-- Ruta al archivo de datos del usuario
local function getUserDataPath()
    local docs = LrPathUtils.getStandardFilePath('documents')
    local folder = LrPathUtils.child(docs, "AutoTagNext_Data")
    return LrPathUtils.child(folder, "user_data.json")
end
Data.getUserDataPath = getUserDataPath

-- Default data structure with presets
local function getDefaultData()
    return {
        activePreset = "municipality",
        presets = {
            municipality = {
                name = "Municipalidad",
                categoryNames = {"Institución", "Área", "Actividad", "Lugar"},
                instituciones = {"Municipalidad Provincial", "Gobierno Regional", "Defensa Civil"},
                areas = {"Alcaldía", "Gerencia Municipal", "Obras Públicas", "Desarrollo Social"},
                actividades = {"Inauguración", "Inspección", "Reunión", "Entrega de Obras"},
                ubicaciones = {"Plaza de Armas", "Auditorio Municipal", "Parque Central"}
            },
            weddings = {
                name = "Bodas",
                categoryNames = {"Familia", "Momento", "Tipo de Foto", "Ubicación"},
                instituciones = {"Familia Novia", "Familia Novio", "Padrinos"},
                areas = {"Ceremonia", "Recepción", "Preparativos", "Luna de Miel"},
                actividades = {"Fotos de Pareja", "Baile", "Brindis", "Intercambio de Votos"},
                ubicaciones = {"Iglesia", "Salón de Eventos", "Jardín", "Hotel"}
            },
            press = {
                name = "Prensa",
                categoryNames = {"Sección", "Alcance", "Tipo de Cobertura", "Ciudad"},
                instituciones = {"Política", "Deportes", "Cultura", "Economía"},
                areas = {"Nacional", "Internacional", "Local", "Regional"},
                actividades = {"Conferencia", "Entrevista", "Cobertura", "Rueda de Prensa"},
                ubicaciones = {"Lima", "Cusco", "Arequipa", "Trujillo"}
            },
            personal = {
                name = "Personal",
                categoryNames = {"Grupo", "Contexto", "Evento", "Lugar"},
                instituciones = {"Familia", "Amigos", "Trabajo"},
                areas = {"Casa", "Viajes", "Eventos", "Hobbies"},
                actividades = {"Cumpleaños", "Paseo", "Celebración", "Reunión Familiar"},
                ubicaciones = {"Hogar", "Parque", "Playa", "Montaña"}
            }
        }
    }
end

-- Helper to ensure directory exists
local function ensureDirectoryExists()
    local path = getUserDataPath()
    local dir = LrPathUtils.parent(path)
    if not LrFileUtils.exists(dir) then
        LrFileUtils.createAllDirectories(dir)
    end
end

-- Load data from JSON file
function Data.load()
    local path = getUserDataPath()
    
    if LrFileUtils.exists(path) then
        local success, content = pcall(function()
            return LrFileUtils.readFile(path)
        end)
        
        if success and content then
            local decoded = JSON.decode(content)
            if decoded and decoded.presets then
                -- Merge with defaults to ensure all presets exist and have correct structure
                local defaults = getDefaultData()
                local mergedData = {
                    activePreset = decoded.activePreset or defaults.activePreset,
                    locationDetails = decoded.locationDetails or {}, -- Preserve locationDetails
                    presets = {}
                }

                for presetId, presetDefaultData in pairs(defaults.presets) do
                    local userPresetData = decoded.presets[presetId]
                    if userPresetData then
                        -- Merge categories within the preset
                        local mergedPreset = { name = userPresetData.name or presetDefaultData.name }
                        for category, defaultItems in pairs(presetDefaultData) do
                            if category ~= "name" then -- 'name' is a string, not a list
                                local userItems = userPresetData[category]
                                if type(userItems) == "table" then
                                    -- Filter out non-string items and ensure uniqueness
                                    local cleanItems = {}
                                    local seen = {}
                                    for _, item in ipairs(userItems) do
                                        if type(item) == "string" and not seen[item] then
                                            table.insert(cleanItems, item)
                                            seen[item] = true
                                        end
                                    end
                                    mergedPreset[category] = cleanItems
                                else
                                    mergedPreset[category] = defaultItems
                                end
                            end
                        end
                        mergedData.presets[presetId] = mergedPreset
                    else
                        -- If user doesn't have this preset, use default
                        mergedData.presets[presetId] = presetDefaultData
                    end
                end
                return mergedData
            end
        end
    end
    
    -- Return defaults if file doesn't exist or is corrupted
    return getDefaultData()
end

-- Get active preset data
function Data.getActivePreset()
    local allData = Data.load()
    local activeId = allData.activePreset or "municipality"
    return allData.presets[activeId] or allData.presets.municipality
end

-- Set active preset
function Data.setActivePreset(presetId)
    local allData = Data.load()
    allData.activePreset = presetId
    Data.saveAll(allData)
end

-- Save all data
function Data.saveAll(data)
    local path = getUserDataPath()
    ensureDirectoryExists()
    
    local success, err = pcall(function()
        local encoded = JSON.stringify(data)
        local file = io.open(path, "w")
        if not file then
            error("No se pudo abrir el archivo para escribir")
        end
        file:write(encoded)
        file:close()
    end)
    
    if not success then
        import 'LrDialogs'.message("Error al guardar", "No se pudo guardar: " .. tostring(err), "critical")
    end
end

-- Add item to active preset
function Data.addItem(category, value)
    if not value or value == "" then return false end

    local allData = Data.load()
    local activeId = allData.activePreset or "municipality"
    local preset = allData.presets[activeId]
    
    if not preset[category] then
        preset[category] = {}
    end
    
    -- Check for duplicates
    for _, v in ipairs(preset[category]) do
        if v == value then
            return false -- Already exists
        end
    end
    
    table.insert(preset[category], value)
    Data.saveAll(allData)
    return true
end

-- Get location details
function Data.getLocationDetails(locationName)
    if not locationName then return nil end
    local allData = Data.load()
    if allData.locationDetails then
        return allData.locationDetails[locationName]
    end
    return nil
end

-- Get all location details
function Data.getAllLocationDetails()
    local allData = Data.load()
    return allData.locationDetails or {}
end

-- Save location details
function Data.saveLocationDetails(locationName, details)
    if not locationName or locationName == "" then return false end
    
    local allData = Data.load()
    if not allData.locationDetails then
        allData.locationDetails = {}
    end
    
    allData.locationDetails[locationName] = details
    Data.saveAll(allData)
    return true
end

-- Get list of available presets
function Data.getPresetList()
    return {
        { id = "municipality", name = "Municipalidad" },
        { id = "weddings", name = "Bodas" },
        { id = "press", name = "Prensa" },
        { id = "personal", name = "Personal" }
    }
end

return Data
