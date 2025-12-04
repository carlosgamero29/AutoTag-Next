-- LocationDialog.lua
-- Dialog to manage detailed location data

local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrBinding = import 'LrBinding'
local LrFunctionContext = import 'LrFunctionContext'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
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
        props.imagePath = "" -- Path to location image
        
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
                -- Load image path if exists
                if details.imagePath and details.imagePath ~= "" then
                    local imagesFolder = Data.getLocationImagesPath()
                    props.imagePath = LrPathUtils.child(imagesFolder, details.imagePath)
                else
                    props.imagePath = ""
                end
            else
                -- If no details saved yet, clear fields but keep name
                props.district = ""
                props.state = ""
                props.country = ""
                props.lat = ""
                props.lon = ""
                props.imagePath = ""
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
                f:combo_box { 
                    value = LrView.bind('district'), 
                    width_in_chars = 30,
                    items = {
                        "Surquillo", "Miraflores", "San Isidro", "Barranco", "San Borja",
                        "La Molina", "Santiago de Surco", "Jesús María", "Lince", "Magdalena",
                        "Pueblo Libre", "San Miguel", "Cercado de Lima", "Breña", "Rímac"
                    },
                    immediate = true
                }
            },
            
            f:row {
                f:static_text { title = "Estado/Prov:", width = 100, alignment = "right" },
                f:combo_box { 
                    value = LrView.bind('state'), 
                    width_in_chars = 30,
                    items = {
                        "Lima", "Callao", "Arequipa", "Cusco", "La Libertad",
                        "Piura", "Lambayeque", "Junín", "Puno", "Ica",
                        "Ancash", "Huánuco", "Ayacucho", "Cajamarca", "Loreto"
                    },
                    immediate = true
                }
            },
            
            f:row {
                f:static_text { title = "País:", width = 100, alignment = "right" },
                f:combo_box { 
                    value = LrView.bind('country'), 
                    width_in_chars = 30,
                    items = {
                        "Perú", "Chile", "Argentina", "Bolivia", "Ecuador",
                        "Colombia", "Brasil", "Venezuela", "Paraguay", "Uruguay"
                    },
                    immediate = true
                }
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
            
            f:separator { fill_horizontal = 1 },
            f:static_text { title = "Imagen de Referencia (Opcional)", font = "<system/small>" },
            
            f:row {
                f:static_text { title = "Imagen:", width = 100, alignment = "right" },
                f:push_button {
                    title = "Seleccionar Imagen...",
                    action = function()
                        local file = LrDialogs.runOpenPanel {
                            title = "Seleccionar imagen de referencia",
                            canChooseFiles = true,
                            canChooseDirectories = false,
                            allowsMultipleSelection = false,
                            fileTypes = { "jpg", "jpeg", "png" }
                        }
                        
                        if file and file[1] then
                            props.imagePath = file[1]
                        end
                    end
                }
            },
            
            
            -- Image preview
            f:row {
                f:static_text { title = "", width = 100 },
                f:column {
                    spacing = 5,
                    
                    -- Show image if available
                    f:picture {
                        value = LrView.bind {
                            key = 'imagePath',
                            transform = function(path)
                                if path and path ~= "" and LrFileUtils.exists(path) then
                                    return path
                                else
                                    return nil
                                end
                            end
                        },
                        width = 200,
                        height = 150,
                        frame_width = 1,
                        frame_color = import 'LrColor'(0.5, 0.5, 0.5),
                        visible = LrView.bind {
                            key = 'imagePath',
                            transform = function(path)
                                return path and path ~= "" and LrFileUtils.exists(path)
                            end
                        }
                    },
                    
                    -- Status text
                    f:static_text {
                        title = LrView.bind {
                            key = 'imagePath',
                            transform = function(path)
                                if path and path ~= "" then
                                    return "✓ Imagen cargada"
                                else
                                    return "Sin imagen de referencia"
                                end
                            end
                        },
                        font = "<system/small>",
                        text_color = LrView.bind {
                            key = 'imagePath',
                            transform = function(path)
                                if path and path ~= "" then
                                    return import 'LrColor'(0, 0.6, 0)
                                else
                                    return import 'LrColor'(0.5, 0.5, 0.5)
                                end
                            end
                        }
                    }
                }
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
            
            -- Handle Image: Copy to location_images folder
            if props.imagePath and props.imagePath ~= "" and LrFileUtils.exists(props.imagePath) then
                local imagesFolder = Data.getLocationImagesPath()
                local fileName = LrPathUtils.leafName(props.imagePath)
                
                -- Create unique filename using location name
                local ext = LrPathUtils.extension(fileName)
                local safeName = props.locationName:gsub("[^%w%s-]", "_") -- Replace special chars
                local newFileName = safeName .. "." .. ext
                local destPath = LrPathUtils.child(imagesFolder, newFileName)
                
                -- Copy file
                local success, err = pcall(function()
                    LrFileUtils.copy(props.imagePath, destPath)
                end)
                
                if success then
                    details.imagePath = newFileName
                end
            end
            
            Data.saveLocationDetails(props.locationName, details)
            
            -- Also add to the preset list if it's new
            local wasNew = Data.addItem("ubicaciones", props.locationName)
            
            -- Update parent UI selection (works for editing existing locations)
            parentProps.temp_location = props.locationName
            
            -- Show appropriate message
            if wasNew then
                LrDialogs.message("Nuevo Lugar Guardado", 
                    "El lugar '" .. props.locationName .. "' se ha guardado correctamente.\n\n" ..
                    "IMPORTANTE: Para que aparezca en el menú desplegable, cierra y vuelve a abrir el plugin.", 
                    "info")
            else
                LrDialogs.message("Guardado", "Datos de ubicación actualizados correctamente.", "info")
            end
        end
    end)
end

return LocationDialog
