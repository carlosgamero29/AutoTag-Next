return {
    LrSdkVersion = 6.0,
    LrSdkMinimumVersion = 6.0,
    
    LrToolkitIdentifier = 'com.carlosgamero.autotagnext.v5', -- Force refresh v5
    LrPluginName = 'AutoTag Next',
    LrPluginInfoUrl = 'https://github.com/carlosgamero29/AutoTag-Next',
    
    LrPluginInfoProvider = 'PluginInfoProvider.lua',
    
    LrLibraryMenuItems = {
        {
            title = "AutoTag Next",
            file = "Main.lua",
        }
    },

    LrFileMenuItems = {
        {
            title = "AutoTag Next",
            file = "Main.lua",
        }
    },
    
    LrHelpMenuItems = {
        {
            title = "Ayuda AutoTag Next",
            file = "Main.lua", -- Just for testing visibility
        }
    },
    
    VERSION = { major = 1, minor = 0, revision = 1, build = 1 },
}
