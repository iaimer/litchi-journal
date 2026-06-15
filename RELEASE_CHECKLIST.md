# Release Checklist

发布前请确认：

- [ ] 更新 `pubspec.yaml` 中的 `version`
- [ ] 更新 `CHANGELOG.md` 中的对应版本内容
- [ ] `dart analyze` 无问题
- [ ] `flutter test` 全部通过
- [ ] `flutter build apk --release` 构建成功
- [ ] 真机安装验证核心功能
- [ ] 关于页显示正确版本号
- [ ] 关于页显示当前版本更新内容
- [ ] 外观主题设置：三种模式均正常工作
- [ ] 深色模式下主要页面可读
- [ ] 标签设置
- [ ] AI 润色

## 构建命令

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
