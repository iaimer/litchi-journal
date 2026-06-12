/// 并发工具函数。
///
/// 对 [items] 中的每个元素执行 [mapper]，
/// 最多同时运行 [concurrency] 个 Future。
/// 单个失败不影响其他，继续执行。
///
/// 返回顺序与 [items] 顺序一致。
Future<List<T>> mapWithConcurrency<T, R>({
  required List<R> items,
  required int concurrency,
  required Future<T> Function(R item) mapper,
}) async {
  if (items.isEmpty) return [];

  final results = List<T?>.filled(items.length, null);

  var index = 0;

  Future<void> worker() async {
    while (index < items.length) {
      final i = index++;
      try {
        results[i] = await mapper(items[i]);
      } catch (_) {
        // 单个失败跳过，results[i] 保持 null
        // 调用方负责处理 null
      }
    }
  }

  // 启动并发 worker
  final futures = <Future<void>>[];
  final workerCount = concurrency < items.length ? concurrency : items.length;
  for (var i = 0; i < workerCount; i++) {
    futures.add(worker());
  }
  await Future.wait(futures);

  // 调用方需自行过滤 null
  return results.cast<T>();
}
