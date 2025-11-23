-- Data.lua
-- Stores the municipality structure (Institutions, Areas, Activities)
-- Now supports saving user additions to a JSON file

local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local JSON = require 'JSON'

local Data = {}

-- Ruta al archivo de datos del usuario
local function getUserDataPath()
    return LrPathUtils.child(LrPathUtils.getStandardFilePath('appData'), "AutoTagNext_UserData.json")
end

-- Valores por defecto si no hay archivo
local defaultData = {
    instituciones = {
        "Municipalidad Provincial",
        "Gobierno Regional",
        "Defensa Civil",
        "Seguridad Ciudadana"
    },
    areas = {
        "Alcaldía",
        "Gerencia Municipal",
        "Imagen Institucional",
        "Obras Públicas",
        "Desarrollo Social",
        "Turismo"
    },
    actividades = {
        "Inauguración",
        "Inspección",
        "Reunión",
        "Ceremonia",
        "Capacitación",
        "Faena Comunal"
    },
    ubicaciones = {
        "Plaza de Armas",
        "Auditorio Municipal",
        "Palacio Municipal",
        "Estadio Municipal"
    }
}

-- Cargar datos desde disco
function Data.load()
    local path = getUserDataPath()
    
    if LrFileUtils.exists(path) then
        local content = LrFileUtils.readFile(path)
        if content then
            local status, data = pcall(JSON.decode, content)
            if status and data then
                -- Fusionar con defaults para asegurar estructura
                for k, v in pairs(defaultData) do
                    if not data[k] then data[k] = v end
                end
                return data
            end
        end
    end
    
    return defaultData
end

-- Guardar datos completos
function Data.saveAll(data)
    local path = getUserDataPath()
    local content = JSON.encode(data)
    LrFileUtils.writeFile(path, content)
end

-- Agregar un nuevo valor a una categoría
function Data.addItem(category, value)
    if not value or value == "" then return false end
    
    local data = Data.load()
    
    if not data[category] then data[category] = {} end
    
    -- Verificar si ya existe (case insensitive)
    local lowerValue = value:lower()
    for _, existing in ipairs(data[category]) do
        if existing:lower() == lowerValue then
            return false -- Ya existe
        end
    end
    
    -- Agregar y guardar
    table.insert(data[category], value)
    Data.saveAll(data)
    return true
end

return Data
