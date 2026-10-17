import 'dart:async';
import 'api_client.dart';

String writeFailureMessage(Object? error, {String fallback = '保存失败，请重试'}) {
  if (error is! ApiException) return fallback;
  if (error.isAuthenticationFailure) return '认证失败，请前往连接设置检查 Token 后重试';
  if (error.isNetworkFailure) return '暂时无法连接服务器，请检查网络后重试';
  return switch (error.statusCode ?? 0) {
    400 || 422 => '内容格式有误，请检查输入后重试',
    404 => '目标日记或记录不存在，请刷新后重试',
    409 => '内容已变化或日记结构异常，请刷新日记后重新确认',
    413 => '图片过大，请在图片设置中降低尺寸或质量',
    429 => '请求过于频繁，请稍后重试',
    >= 500 => '服务器暂时无法保存，请稍后重试',
    _ => error.message == '记录已发生变化，请刷新日记后重新确认' ? error.message : fallback,
  };
}

String diaryReadFailureMessage(
  Object error, {
  required bool hasLocalContent,
  String fallback = '日记加载失败，请重试',
}) {
  if (error is ApiException && error.isAuthenticationFailure) {
    return '认证失败，请检查连接设置后重试';
  }
  if (error is TimeoutException ||
      (error is ApiException && error.isNetworkFailure)) {
    return hasLocalContent ? '暂时无法连接，正在显示本地内容' : '无法连接服务器，此日记尚未缓存，连接后请重试';
  }
  final String message;
  if (error is FormatException || error is TypeError) {
    message = '服务器返回的日记数据无法解析，请重试或检查服务器版本';
  } else if (error is ApiException && error.statusCode != null) {
    message = error.statusCode! >= 500
        ? '服务器错误（${error.statusCode}），请稍后重试'
        : '日记请求失败（${error.statusCode}），请重试';
  } else if (error is ApiException &&
      const ['今日日记创建失败，请重试', '今日日记暂时无法读取，请重试'].contains(error.message)) {
    message = error.message;
  } else {
    message = fallback;
  }
  return hasLocalContent ? '$message；正在显示本地内容' : message;
}
