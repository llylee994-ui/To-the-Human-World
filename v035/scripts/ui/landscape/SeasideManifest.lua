-- Design coordinates from the approved seaside concept; image aspect stays native.
local SeaArt=require "ui.landscape.SeaArt"
return {
    width=1920,height=1080,
    background=SeaArt.background,foreground=SeaArt.dockForeground,
    bottle={path="image/seaside-r1/bottle.png",x=1110,y=815,width=190,height=190},
    net={path="image/seaside-r1/net.png",width=600,height=600},
    ship={path="image/misty-harbor-r1/merchant-ship-muted.png",x=580,y=485,width=270,height=244,rotation=0},
    shipObject={id="seaside.merchantShip",layer=1,minTouch=55,regions={
        {kind="ellipse",cx=.47,cy=.34,w=.57,h=.62,keepInsideCanvas=true},
    }},
}
