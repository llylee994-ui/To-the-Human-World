-- One readable handwriting family for menus, letters, brewing and the harbor.
local Theme=require "urhox-libs/UI/Core/Theme"
return Theme.ExtendTheme(assert(Theme.GetRegisteredTheme("default-dark")),{
    typography={fontFamily="story"},
    colors={
        primary={91,61,39,255},primaryHover={112,78,49,255},primaryPressed={69,44,29,255},
        secondary={81,97,82,255},secondaryHover={104,119,99,255},secondaryPressed={60,76,64,255},
        background={48,42,34,255},surface={238,226,201,255},surfaceAlt={225,211,185,255},
        text={65,46,28,255},textSecondary={112,91,64,255},disabledText={148,131,109,255},
        border={0,0,0,0},borderFocus={154,122,77,255},
    },
    components={Button={fontFamily="story",fontWeight="normal",borderWidth=0,glowShadow={},pressedPadding=0}},
})
