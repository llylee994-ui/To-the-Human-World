-- Isolated in-memory Lab using the complete native 3D scene and pinned main UI.
require("v035.lab35.FullSceneHost").Install({resourcePrefix="v035-full",manifestPath="manifest.json",flipV=true,maxLoadingSeconds=900,
    deferLoadingViewport=true,loadingMaxSteps=64,loadingBudgetMs=50,cloudHdr=true,cloudNoLut=true,lightingPreset="warm_harbor"})
