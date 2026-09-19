# 第三方资源说明

## Lucide Icons

本项目静态图标取自 Lucide `1.47.0`：

- 来源：[Lucide Icons](https://lucide.dev/)
- 固定版本：[lucide-static@1.47.0](https://github.com/lucide-icons/lucide/releases/tag/1.47.0)
- 资源形式：官方 SVG，随 App 本地打包。
- 许可：ISC License；其中列出的 Feather 派生图标同时附带 MIT License。

以下文本摘自上游 `lucide-static@1.47.0/LICENSE`：

```text
ISC License

Copyright (c) 2026 Lucide Icons and Contributors

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

---

The following Lucide icons are derived from the Feather project:

airplay, alert-circle, alert-octagon, alert-triangle, aperture, arrow-down-circle, arrow-down-left, arrow-down-right, arrow-down, arrow-left-circle, arrow-left, arrow-right-circle, arrow-right, arrow-up-circle, arrow-up-left, arrow-up-right, arrow-up, at-sign, calendar, cast, check, chevron-down, chevron-left, chevron-right, chevron-up, chevrons-down, chevrons-left, chevrons-right, chevrons-up, circle, clipboard, clock, code, columns, command, compass, corner-down-left, corner-down-right, corner-left-down, corner-left-up, corner-right-down, corner-right-up, corner-up-left, corner-up-right, crosshair, database, divide-circle, divide-square, dollar-sign, download, external-link, feather, frown, hash, headphones, help-circle, info, italic, key, layout, life-buoy, link-2, link, loader, lock, log-in, log-out, maximize, meh, minimize, minimize-2, minus-circle, minus-square, minus, monitor, moon, more-horizontal, more-vertical, move, music, navigation-2, navigation, octagon, pause-circle, percent, plus-circle, plus-square, plus, power, radio, rss, search, server, share, shopping-bag, sidebar, smartphone, smile, square, table-2, tablet, target, terminal, trash-2, trash, triangle, tv, type, upload, x-circle, x-octagon, x-square, x, zoom-in, zoom-out

The MIT License (MIT) (for the icons listed above)

Copyright (c) 2013-present Cole Bemis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Lordicon

本项目使用以下 Lordicon FREE 动态图标，均于 2026-09-19 从 Lordicon 官方编辑器导出为仅含 `in-reveal` 状态的 Lottie JSON，并另存对应静态 SVG 作为减少动态效果和加载失败时的回退：

| 图标 | ID 与来源 | 状态 | 许可 |
|---|---|---|---|
| Book | [system-outline-4092-book](https://lordicon.com/icons/system/outline/4092-book) | `in-reveal` | FREE |
| Check | [system-outline-37-check](https://lordicon.com/icons/system/outline/37-check) | `in-reveal` | FREE |

- 许可说明：[Lordicon Free License](https://lordicon.com/docs/license/free)
- 署名规则：[Attribution](https://lordicon.com/docs/license/attribution)
- 播放引擎：[Lottie for Flutter](https://pub.dev/packages/lottie)，`lottie` 包 `3.6.1`；动画资源由 Lordicon 官方导出，不从网络加载。
- 官方 Flutter 封装 `lordicon` `1.0.3` 的传递依赖要求旧版 Lottie 与 `archive 3.x`，无法和项目当前 `image 4.x` 依赖同时解析。为避免无关降级图片处理依赖，项目直接使用 `lottie 3.6.1` 播放官方导出的资源；动画来源、内容与署名规则不变。
- 免费图标可用于应用，但不得无署名使用或作为独立图标素材再分发。
- 移动应用须在 About 页面提供可点击来源链接，并在 Google Play / App Store 应用描述中标注 `Animated icons by Lordicon.com`。

## Runtime packages

- `flutter_svg` 用于本地 SVG 渲染。
- Lordicon JSON 由应用内的 Lottie 播放引擎播放一次；每份 JSON 仅保留 `in-reveal` 状态。减少动态效果开启时不加载动画 JSON，改用配套静态 SVG。
