-- Data.lua
-- Stores the municipality structure (Institutions, Areas, Activities)

local Data = {}

-- Load data from disk or use defaults
function Data.load()
    -- In a real implementation, this could load from a JSON file or LrPrefs
    -- For now, we return the structure to be populated
    return {
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
end

return Data
