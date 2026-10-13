# 纹理颜色空间上传顺序回归

官方 Linux Runtime 20260924-1343-91bee56，真实 GLES、HDR、固定曝光、TONEMAP_MODE_NONE。
同一张128灰图片的三块无光照灰牌实测：
- 线性常量0.2158605：输出128
- SetData后SetSRGB(true)：输出187，发灰
- SetSRGB(true)后SetData：输出128

修复：在创建GPU纹理前确定颜色空间，读取Image→创建Texture2D→SetSRGB→SetData；按路径与颜色空间缓存。基础色sRGB=true，法线false。没有改灯光、曝光、贴图像素或模型。

整屋同机位1170×658于2026-10-13完成，100网格、3,208,608面、8锚点校准通过；加载71.015秒，READY后20帧截图成功。窗外与木纹恢复深色，但室内照明仍待改善，不能当作美术完成。

当前NONE是绕过LUT色调映射路径，并非已验证显式tonemapLUTEnabled=false。未采用输入颜色预补偿。Windows/目标设备尚未回归。
