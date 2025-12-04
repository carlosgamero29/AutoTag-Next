-- LocationDialog.lua
-- Dialog to manage detailed location data

local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrBinding = import 'LrBinding'
local LrFunctionContext = import 'LrFunctionContext'
local Data = require 'Data'

local LocationDialog = {}

function LocationDialog.show(parentProps)
    LrFunctionContext.callWithContext("Location Manager", function(context)
        local f = LrView.osFactory()
        local props = LrBinding.makePropertyTable(context)
        
        -- Initial values
        props.locationName = parentProps.temp_location or ""
        props.district = ""
        props.state = ""
        props.country = ""
        props.lat = ""
        props.lon = ""
        
        -- Load existing locations list
        local locationList = { "-- Seleccionar para cargar --" }
        local seen = {}
        
        local function add(name)
            if name and type(name) == "string" and name ~= "" and not seen[name] then
                table.insert(locationList, name)
                seen[name] = true
            end
        end

        -- 1. From Preset
        local preset = Data.getActivePreset()
        if preset and preset.ubicaciones then
            for _, loc in ipairs(preset.ubicaciones) do
                add(loc)
            end
        end
        
        -- 2. From Saved Details
        local allDetails = Data.getAllLocationDetails()
        if allDetails then
            for name, _ in pairs(allDetails) do
                add(name)
            end
        end
        
        -- Sort (skipping the first item)
        if #locationList > 1 then
            local toSort = {}
            for i = 2, #locationList do
                table.insert(toSort, locationList[i])
            end
            table.sort(toSort)
            
            -- Rebuild
            locationList = { "-- Seleccionar para cargar --" }
            for _, name in ipairs(toSort) do
                table.insert(locationList, name)
            end
        end
        
        props.savedLocations = locationList
        props.selectedSavedLocation = locationList[1]
        
        -- Function to load data for a specific location
        local function loadLocationData(name)
            if not name or name == "" then return end
            
            -- If user selects from dropdown, update the name field too
            props.locationName = name
            
            local details = Data.getLocationDetails(name)
            if details then
                props.district = details.district or ""
                props.state = details.state or ""
                props.country = details.country or ""
                if details.gps then
                    props.lat = details.gps.latitude or ""
                    props.lon = details.gps.longitude or ""
                else
                    props.lat = ""
                    props.lon = ""
                end
            else
                -- If no details saved yet, clear fields but keep name
                props.district = ""
                props.state = ""
                props.country = ""
                props.lat = ""
                props.lon = ""
            end
        end
        
        -- Initial load if name passed
        if props.locationName ~= "" then
            loadLocationData(props.locationName)
        end
        
        -- Observer for dropdown
        props:addObserver('selectedSavedLocation', function()
            local sel = props.selectedSavedLocation
            if sel and sel ~= "-- Seleccionar para cargar --" then
                loadLocationData(sel)
            end
        end)
        
        local content = f:column {
            bind_to_object = props,
            spacing = f:control_spacing(),
            width = 450,
            
            f:static_text { 
                title = "Gestionar Detalles de Ubicación", 
                font = "<system/bold>",
                alignment = "center",
                fill_horizontal = 1
            },
            
            f:separator { fill_horizontal = 1 },
            
            -- Load Existing Section
            f:row {
                f:static_text { title = "Cargar Existente:", width = 100, alignment = "right" },
                f:popup_menu {
                    items = LrView.bind('savedLocations'),
                    value = LrView.bind('selectedSavedLocation'),
                    width_in_chars = 30
                }
            },
            
            f:separator { fill_horizontal = 1 },
            
            f:row {
                f:static_text { title = "Lugar:", width = 100, alignment = "right" },
                f:edit_field { 
                    value = LrView.bind('locationName'), 
                    width_in_chars = 30,
                    enabled = true
                }
            },
            
            f:row {
                f:static_text { title = "Distrito:", width = 100, alignment = "right" },
                f:edit_field { value = LrView.bind('district'), width_in_chars = 30 }
            },
            
            f:row {
                f:static_text { title = "Estado/Prov:", width = 100, alignment = "right" },
                f:edit_field { value = LrView.bind('state'), width_in_chars = 30 }
            },
            
            f:row {
                f:static_text { title = "País:", width = 100, alignment = "right" },
                f:edit_field { value = LrView.bind('country'), width_in_chars = 30 }
            },
            
            f:separator { fill_horizontal = 1 },
            f:static_text { title = "Coordenadas GPS (Opcional)", font = "<system/small>" },
            
            f:row {
                f:static_text { title = "Latitud:", width = 100, alignment = "right" },
                f:edit_field { 
                    value = LrView.bind('lat'), 
                    width_in_chars = 15,
                    placeholder = "-12.0000" 
                }
            },
            
            f:row {
                f:static_text { title = "Longitud:", width = 100, alignment = "right" },
                f:edit_field { 
                    value = LrView.bind('lon'), 
                    width_in_chars = 15,
                    placeholder = "-77.0000"
                }
            },
            
            f:static_text { 
                title = "Formato: Decimal (ej: -12.1234). Usa los placeholders como guía.",
                font = "<system/small>",
                text_color = import 'LrColor'(0.5, 0.5, 0.5),
                alignment = "center",
                fill_horizontal = 1
            },
            
            f:static_text { 
                title = "Nota: Estos datos se aplicarán automáticamente al seleccionar este lugar.",
                font = "<system/small>",
                text_color = import 'LrColor'(0.5, 0.5, 0.5)
            }
        }
        
        local result = LrDialogs.presentModalDialog {
            title = "Editor de Ubicaciones",
            contents = content,
            actionVerb = "Guardar",
            cancelVerb = "Cancelar"
        }
        
        if result == "ok" then
            -- Validate and Save
            if props.locationName == "" then
                LrDialogs.message("Error", "El nombre del lugar no puede estar vacío", "critical")
                return
            end
            
            local details = {
                district = props.district,
                state = props.state,
                country = props.country
            }
            
            -- Handle GPS
            local lat = tonumber(props.lat)
            local lon = tonumber(props.lon)
            if lat and lon then
                details.gps = { latitude = lat, longitude = lon }
            end
            
            Data.saveLocationDetails(props.locationName, details)
            
            -- Also add to the preset list if it's new
            Data.addItem("ubicaciones", props.locationName)
            
            -- Update parent UI if needed
            parentProps.temp_location = props.locationName
            
            LrDialogs.message("Guardado", "Datos de ubicación guardados correctamente.", "info")
        end
    end)
end

return LocationDialog
