import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'storage_manager_widgets.dart';

/// storage_manager.dart 의 Local / Session Storage 표에 들어가는 [DataRow] 를
/// 만드는 데 필요한 것들.
///
/// 원래 `_buildLocalStorageRow` 와 `_buildSessionStorageRow` 는 대상 [Storage]
/// 와 편집 추적 리스트만 다르고 나머지가 같았다. 그 둘을 그대로 옮겨 하나로
/// 합친 것이며 동작은 같다.
class WebStorageRowContext {
  const WebStorageRowContext({
    required this.constraints,
    required this.storage,
    required this.keyTrackingEdit,
    required this.valueTrackingEdit,
    required this.onRefresh,
  });

  final BoxConstraints constraints;

  /// `webViewController?.webStorage.localStorage` 또는 `.sessionStorage`.
  /// 컨트롤러가 없으면 null 이고, 원본의 `?.` 와 같은 자리에 놓인다.
  final Storage? storage;

  final List<bool> keyTrackingEdit;
  final List<bool> valueTrackingEdit;

  /// 원본의 `setState(() {})`.
  final VoidCallback onRefresh;
}

DataRow buildWebStorageRow(
  WebStorageRowContext ctx,
  WebStorageItem webStorageItem,
  int index,
) {
  return DataRow(cells: <DataCell>[
    buildEditableStorageDataCell(
      EditableStorageDataCellConfig(
        width: ctx.constraints.maxWidth / 3,
        onFieldSubmitted: (newValue) async {
          final updateItemValue =
              await ctx.storage?.getItem(key: webStorageItem.key!);
          await ctx.storage?.removeItem(key: webStorageItem.key!);
          await ctx.storage?.setItem(key: newValue, value: updateItemValue);
        },
        initialValue: webStorageItem.key!,
        index: index,
        trackingEditStatus: ctx.keyTrackingEdit,
        onRefresh: ctx.onRefresh,
      ),
    ),
    buildEditableStorageDataCell(
      EditableStorageDataCellConfig(
        width: ctx.constraints.maxWidth / 3,
        onFieldSubmitted: (newValue) async {
          await ctx.storage?.setItem(key: webStorageItem.key!, value: newValue);
        },
        initialValue: webStorageItem.value,
        index: index,
        trackingEditStatus: ctx.valueTrackingEdit,
        onRefresh: ctx.onRefresh,
      ),
    ),
    _deleteStorageItemCell(ctx, () async {
      await ctx.storage?.removeItem(key: webStorageItem.key!);
    }),
  ]);
}

DataCell _deleteStorageItemCell(
  WebStorageRowContext ctx,
  Future<void> Function() onDelete,
) {
  return DataCell(IconButton(
    icon: const Icon(Icons.cancel),
    onPressed: () async {
      await onDelete();
      ctx.onRefresh();
    },
  ));
}
