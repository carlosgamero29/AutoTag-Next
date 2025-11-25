-- PhotoNavigation.lua
-- Photo navigation and metadata loading logic

local LrPrefs = import 'LrPrefs'

local PhotoNavigation = {}

-- Helper to load metadata for current photo
function PhotoNavigation.loadPhotoMetadata(props)
    local photo = props.currentPhoto
    if not photo then return end
    
    props.title = photo:getFormattedMetadata('title') or ""
    props.description = photo:getFormattedMetadata('caption') or ""
    
    -- Cargar keywords existentes
    local existingKeywords = photo:getFormattedMetadata('keywordTags')
    if existingKeywords then
        props.keywords = existingKeywords
    else
        props.keywords = ""
    end
    
    props.photoCounter = props.currentIndex .. " / " .. props.totalPhotos
end

-- Setup observers for photo changes and persistence
function PhotoNavigation.setupObservers(props)
    local prefs = LrPrefs.prefsForPlugin()
    
    -- Observer for photo changes (Critical for preview update)
    props:addObserver('currentPhoto', function()
        PhotoNavigation.loadPhotoMetadata(props)
    end)

    -- Observers for persistence
    local function savePref(key, value)
        prefs[key] = value
    end
    
    props:addObserver('userContext', function(_, _, value) savePref('lastUserContext', value) end)
    props:addObserver('institution', function(_, _, value) savePref('lastInstitution', value) end)
    props:addObserver('area', function(_, _, value) savePref('lastArea', value) end)
    props:addObserver('activity', function(_, _, value) savePref('lastActivity', value) end)
    props:addObserver('location', function(_, _, value) savePref('lastLocation', value) end)
end

-- Navigate to next photo
function PhotoNavigation.nextPhoto(props)
    if props.currentIndex < props.totalPhotos then
        props.currentIndex = props.currentIndex + 1
        props.currentPhoto = props.photos[props.currentIndex] -- Trigger observer
    end
end

-- Navigate to previous photo
function PhotoNavigation.prevPhoto(props)
    if props.currentIndex > 1 then
        props.currentIndex = props.currentIndex - 1
        props.currentPhoto = props.photos[props.currentIndex] -- Trigger observer
    end
end

return PhotoNavigation
