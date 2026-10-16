# 游戏物件音效来源

此目录仅播放 manifest.json 所列八份 WAV。五份使用 2026-10-15-object-feedback-v2，信件和书本三份使用 2026-10-15-paper-book-soft；导入时逐字节复制，不再处理响度或归一化，单文件增益 1.0，不循环。

素材是 Kenney（RPG Audio、Impact Sounds）及 Joseph SARDIN / BigSoundBank 的 CC0 1.0 录音经剪辑制作，并非本项目独立录制。原作者、具体网址、加工配方、哈希和原包许可证保存在 sources/ 两个来源包下。

- Kenney RPG Audio: https://kenney.nl/assets/rpg-audio
- Kenney Impact Sounds: https://kenney.nl/assets/impact-sounds
- BigSoundBank: https://bigsoundbank.com/wooden-drawer-opening-s1499.html 、 https://bigsoundbank.com/tiroir-en-bois-fermeture-s1500.html 、 https://bigsoundbank.com/splash-small-6-s1534.html
- CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/

sources/ 保留的是原包历史材料，里面列出的旧信件/旧书本并非本次运行资源；本目录 manifest.json 的八项映射为准。原始试听 WAV、网页、合集与素材录音仍保留在项目之外原 audio-studies 目录，不移动或覆盖。运行代码只引用 audio/sfx/objects/ 下项目资源，不依赖制作者电脑路径。
