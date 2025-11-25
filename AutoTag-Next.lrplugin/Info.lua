return {
    LrSdkVersion = 6.0,
    LrSdkMinimumVersion = 6.0,
    
    LrToolkitIdentifier = 'com.carlosgamero.autotagnext.v5', -- Force refresh v5
    LrPluginName = 'AutoTag Next',
    LrPluginInfoUrl = 'https://github.com/carlosgamero29/AutoTag-Next',
    
    LrPluginInfoProvider = 'PluginInfoProvider.lua',
    
    LrLibraryMenuItems = {
        {
            title = "AutoTag Next - Análisis con IA",
            file = "Main.lua",
        }
    },

    LrExportMenuItems = {
        {
            title = "AutoTag Next - Análisis con IA",
            file = "Main.lua",
        }
    },
    
    VERSION = { major = 1, minor = 0, revision = 2, build = 2 },
}
