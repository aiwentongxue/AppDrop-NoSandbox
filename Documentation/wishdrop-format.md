# Wishdrop 文件格式（.wishdrop）

- 底层格式：JSON（UTF-8）；扩展开名：`.wishdrop`；UTI：`com.appdrop.wishdrop`（声明于 App 的 Info.plist，符合 `public.json`）。
- 导入采用系统文件选择器或 Finder 双击（`application(_:open:)`），导入不会清空既有追踪列表。

## 结构

```json
{
  "formatIdentifier": "com.appdrop.wishdrop",
  "version": 1,
  "title": "AppDrop Wishlist",
  "author": "可选",
  "exportedAt": "2026-10-13T05:40:00Z",
  "apps": [
    {
      "trackId": "6502622570",
      "name": "Infinity Nikki",
      "countryCode": "us",
      "appStoreURL": "https://apps.apple.com/us/app/infinity-nikki/id6502622570?uo=4"
    }
  ]
}
```

字段说明：

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `formatIdentifier` | 是 | 必须等于 `com.appdrop.wishdrop` |
| `version` | 是 | 当前支持 ≤ 1；更高版本会给出明确错误而不是强行导入 |
| `title` / `exportedAt` | 是 | 预设名称与导出时间（ISO 8601） |
| `author` | 否 | 作者 |
| `apps[].trackId` | 是 | 6–12 位纯数字 |
| `apps[].name` | 是 | 非空 |
| `apps[].countryCode` | 是 | `us` / `hk` / `jp` / `cn`（大小写不敏感） |
| `apps[].appStoreURL` | 否 | 若存在必须是 http(s) 链接 |

## 导入行为

- 逐条校验：非法应用 ID、未知区域、空名称、非法 URL 不会被写入，并会在导入摘要中逐条列出原因。
- 重复（同一 `trackId + 区域` 已追踪）不会重复创建，计入“已存在”。
- 逐条写入前再次执行逻辑唯一键检查，避免并发/重复导入产生双份记录。
- 导入的条目在首次成功查价前显示“价格待获取”（不会用 0 元占位）。

## 导出行为

- 导出当前追踪列表（含 `trackId / name / countryCode` 与规范化的 `App Store URL`）。
- 使用系统保存面板，默认文件名 `AppDrop-Wishlist.wishdrop`。

