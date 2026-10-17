# 入口音效与《夜色里的配方》来源

本批仅使用 brewing-manifest.json 中的三份资源。用户于 2026-10-16 确认试听版本，初次导入均逐字节复制；随后用户反馈捞网和药炉入口音效在 BGM 下不够明显，按此要求将这两份导入 WAV 的样本振幅统一乘以 1.6（约 +4.08 dB），没有削波、归一化、压缩或变速。炼药 BGM 保持与交付文件逐字节一致。运行时单文件增益基准仍为 1.0，沿用用户音效开关和音量。运行路径均相对 assets，外部 audio-studies 中的原始试听文件与工程不作修改；原始及当前资源哈希见 brewing-manifest.json。

- `sfx/objects/net_pick.wav`：来自 `2026-10-16-net-and-brewing/sfx/net_pick.wav`，0.40 秒。由 Kenney Impact Sounds / RPG Audio 的木头、衣带、皮革 CC0 录音加工组合；作者 Kenney，https://kenney.nl/assets/impact-sounds 、 https://kenney.nl/assets/rpg-audio 。
- `sfx/objects/stove_touch.wav`：来自 `2026-10-16-brewing-mystery-v2/sfx/stove_touch.wav`，0.52 秒。使用 Kenney Impact Sounds 的 `impactMetal_medium_000.ogg`（CC0），加工后叠加本地合成炉体共鸣与短炉火声。没有使用旧 click-feedback 同名文件。
- `bgm/brewing-mystery-loop.wav`：《夜色里的配方》第二版，84 秒。按原包制作说明，旋律、配器、音色与锅边环境层均为本地编写和合成，无钢琴采样、成曲片段或人声。此文件已经包含环境声，不再单独播放 ambience-loop.wav。

CC0 1.0：https://creativecommons.org/publicdomain/zero/1.0/ 。原包 CREDITS、音效加工来源及 Kenney 许可证保存在 `sources/2026-10-16-net-and-brewing/` 与 `sources/2026-10-16-brewing-mystery-v2/`。

上述 sources 目录保留的是原包历史说明，可能提及第一版钢琴或试听对照；这些音乐、采样、独立环境声和对照片段均未作为本批资源导入。运行资源及哈希以 brewing-manifest.json 为准。
