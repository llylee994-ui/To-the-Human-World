-- Approved immutable decoration catalog; blank paper is an independent unlettered item.
local D={list={},byId={}}
local function add(row) D.list[#D.list+1]=row;D.byId[row.id]=row end
add {id="daisy",label="雏菊",path="image/wish-collage-r1/botanical-atlas.png",width=1774,height=887,x=122,y=79,w=232,h=353,displayHeight=155}
add {id="forget-me-not",label="勿忘我",path="image/wish-collage-r1/botanical-atlas.png",width=1774,height=887,x=544,y=35,w=288,h=409,displayHeight=155}
add {id="lavender",label="薰衣草",path="image/wish-collage-r1/botanical-atlas.png",width=1774,height=887,x=1009,y=23,w=180,h=417,displayHeight=155}
add {id="sage",label="鼠尾草叶",path="image/wish-collage-r1/botanical-atlas.png",width=1774,height=887,x=1372,y=26,w=329,h=405,displayHeight=155}
add {id="fern",label="蕨叶",path="image/wish-collage-r1/botanical-atlas.png",width=1774,height=887,x=84,y=451,w=298,h=404,displayHeight=155}
add {id="wheat",label="麦穗",path="image/wish-collage-r1/botanical-atlas.png",width=1774,height=887,x=569,y=444,w=276,h=412,displayHeight=155}
add {id="buttercup",label="毛茛小黄花",path="image/wish-collage-r1/botanical-atlas.png",width=1774,height=887,x=966,y=466,w=302,h=388,displayHeight=155}
add {id="pink-wildflower",label="粉色野花",path="image/wish-collage-r1/botanical-atlas.png",width=1774,height=887,x=1422,y=456,w=261,h=399,displayHeight=155}
add {id="paper-short",label="空白短纸条",path="image/wish-collage-r1/blank-slip-short.png",width=1650,height=953,x=289,y=239,w=1076,h=456,displayHeight=48}
add {id="paper-medium",label="空白中纸条",path="image/wish-collage-r1/blank-slip-medium.png",width=2172,height=724,x=16,y=90,w=2144,h=548,displayHeight=48}
add {id="paper-long",label="空白长纸条",path="image/wish-collage-r1/blank-slip-long.png",width=2172,height=724,x=15,y=169,w=2140,h=386,displayHeight=48}
return D
