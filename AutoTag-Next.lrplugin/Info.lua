return {
    LrSdkVersion = 6.0,
    LrSdkMinimumVersion = 6.0,
    
    LrToolkitIdentifier = 'com.carlosgamero.autotagnext.v3', -- New ID to clear registry
    LrPluginName = 'AutoTag Next',
    LrPluginInfoUrl = 'https://github.com/carlosgamero29/AutoTag-Next',
    
    LrPluginInfoProvider = 'PluginInfoProvider.lua',
    
    LrLibraryMenuItems = {
        {
            title = "AutoTag Next - Analizar Fotos",
            file = "Main.lua",
        }
    },
    
    VERSION = { major = 1, minor = 0, revision = 0, build = 1 },
}
