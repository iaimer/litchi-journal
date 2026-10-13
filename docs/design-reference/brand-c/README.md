# C 方案品牌验收图

母版是 `../brand-c-master.png`（517×373，透明 PNG），从已确认的 `../brand-c-approved.png` 右侧 C 图原始像素裁取并分离外部底色；保留书页填充、荔枝、爱心与抗锯齿边缘，不采用后续生成的光晕图。审查阶段进一步清除书本外低透明阴影，仅移除距实体轮廓超过 2px 的低透明像素，实体像素保持原样。

图标资源由 `tools/derive_brand_assets.cjs` 从母版统一派生。在已安装 sharp 的 Node 工具环境执行，必要时通过 `NODE_PATH` 指向其包目录；不新增 Flutter / npm 运行依赖。Android 自适应前景图层 108dp、图形宽 54dp，全部非透明像素落在中心 66dp 安全圆内；桌面底色为 `#FAFAFA`。页面直接使用透明母版，图形宽为标题实测宽的 95%。

`splash-light.png`、`splash-dark.png`、`about-light.png`、`about-dark.png` 为本轮实际 Flutter Widget 渲染图，视口 390×844、2 倍输出；`pages-overview.png` 为四图缩略拼接，依次为浅色启动、浅色关于、深色启动、深色关于。采集环境临时加载本机中文字体，仅用于预览，不随 App 打包。关于页采集为独立根路由，无前一页面，因此无返回箭头；正式路由返回行为保持原样。图片不是真机截图。

2026-10-13 ADB 无 PLG110 设备，桌面与冷启动、关于页真机验收仍待连接。正式装机使用 HANDOFF 指定的品牌测试 APK，保留用户现有配置。
