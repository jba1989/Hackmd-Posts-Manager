# HackMD Sync System

完整的 HackMD 本地同步系統，支援雙向同步、衝突檢測、智慧 Frontmatter 處理。

## 功能特色

- ✅ **雙向同步** - 支援從 HackMD 拉取 (Pull) 和推送 (Push) 文章
- ✅ **衝突檢測** - MD5 內容比對，防止意外覆蓋
- ✅ **智慧 Frontmatter** - 保留 HackMD 官方欄位，自動管理自定義欄位
- ✅ **狀態追蹤** - 避免重複上傳未修改的檔案，減少 API 使用次數
- ✅ **批量操作** - 支援單檔或批量同步

## 快速開始

### 1. 安裝依賴

```bash
npm install -g @hackmd/hackmd-cli
```

### 2. 配置 API Token

在 [HackMD Settings](https://hackmd.io/settings#api) 建立 API token，然後創建 `.env` 檔案：

```bash
HMD_API_ACCESS_TOKEN=your_token_here
```

### 3. 基本使用

```bash
# 匯出所有文章
./scripts/export.sh

# 編輯文章
vim posts/my-article.md

# 推送更新
./scripts/update.sh "my-article.md"

# 批量同步所有修改
./scripts/sync.sh
```

## 系統架構

### 檔案結構

```
.
├── posts/                # 文章目錄
│   ├── .sync_state      # 同步狀態追蹤
│   ├── index.json       # 文章索引
│   └── *.md             # Markdown 文章
├── scripts/
│   ├── export.sh        # 匯出（Pull）
│   ├── update.sh        # 單篇推送（Push）
│   └── sync.sh          # 批量推送
└── .env                 # API Token
```

### 工作流程

```
        HackMD Cloud ☁️
              ↕
    ┌─────────┴─────────┐
    ↓                   ↓
export.sh           update.sh
(Pull)              (Push)
    ↓                   ↑
    └─────────┬─────────┘
              ↓
        本地檔案 📄
    (posts/*.md + .sync_state)
              ↑
          sync.sh
        (批量 Push)
```

## 核心功能

### 1. Export (Pull) - 從 HackMD 下載

#### 匯出所有文章
```bash
./scripts/export.sh
```

#### 匯出單篇文章（Pull 功能）
```bash
./scripts/export.sh "article.md"
```

**衝突檢測：**
- 若本地檔案與遠端內容不同，會顯示警告並跳過
- 使用 `--force` 強制覆蓋本地修改

```bash
./scripts/export.sh "article.md" --force
```

#### 特性
- ✅ MD5 內容比對
- ✅ 保留 HackMD 原有 frontmatter
- ✅ 添加自定義管理欄位
- ✅ 生成文章索引檔
- ✅ 處理特殊字元檔名（中文、空格、符號）

### 2. Update (Push) - 上傳至 HackMD

```bash
./scripts/update.sh "article.md"
```

#### 特性
- ✅ 從 frontmatter 讀取 `hackmd_id`
- ✅ 智慧過濾：保留官方欄位，移除自定義欄位
- ✅ 自動更新 `.sync_state`

### 3. Sync (Batch Push) - 批量同步

```bash
./scripts/sync.sh
```

#### 特性
- ✅ 自動掃描 `posts/` 目錄
- ✅ 比對檔案修改與匯出的時間，只上傳有修改的檔案
- ✅ 提供執行摘要（成功/失敗/跳過數量）

**強制同步所有檔案：**
```bash
./scripts/sync.sh --force
```

## Frontmatter 處理策略

### 官方欄位（上傳時保留）

HackMD 原生支援的欄位會被保留：
- `title` - 文章標題
- `tags` - 標籤
- `image` - 封面圖
- `description` - 描述
- `robots`, `lang`, `breaks`, `GA` 等

### 自定義欄位（上傳時移除）

僅用於本地管理：
- `hackmd_id` - 文章 ID（用於更新）
- `userPath` - 使用者路徑

### Frontmatter 範例

```yaml
---
# HackMD 官方欄位（上傳時保留）
title: My Article
tags: tutorial, notes
image: https://example.com/cover.jpg

# 自定義欄位（上傳時移除）
hackmd_id: abc123xyz
userPath: username
---
```

## 使用情境

### 情境 1：在 HackMD 編輯後同步到本地

```bash
# HackMD 網站編輯後，拉取最新版本
./scripts/export.sh "article.md"

# 若本地也有修改 → 顯示衝突警告
# 若本地未修改 → ✓ No changes detected
```

### 情境 2：本地編輯後推送到 HackMD

```bash
# 本地編輯
vim "posts/article.md"

# 單篇上傳
./scripts/update.sh "article.md"

# 或批量同步
./scripts/sync.sh
```

### 情境 3：雙方都修改（衝突處理）

```bash
# 嘗試 pull
./scripts/export.sh "article.md"
# ⚠ Conflict detected!

# 選項 1: 保留本地版本，推送到 HackMD
./scripts/update.sh "article.md"

# 選項 2: 放棄本地修改，使用遠端版本
./scripts/export.sh "article.md" --force
```

## 核心機制

### 1. 雙重記錄架構
- **JSON 索引** (`index.json`) - 提供整體視圖，方便批量操作
- **YAML Frontmatter** - 每個檔案自包含 metadata，即使索引丟失也能恢復

### 2. 同步狀態追蹤 (`.sync_state`)
- 記錄每個檔案最後同步時間（Unix 時間戳）
- 避免重複上傳未修改的檔案
- 自動更新於 export、update、sync 操作後

### 3. 衝突檢測
- MD5 比對本地與遠端內容
- 只比較文章正文（排除 frontmatter）
- 預防意外覆蓋，保護資料安全

## 腳本功能總覽

| 腳本 | 功能 | 衝突處理 | 狀態追蹤 |
|------|------|----------|----------|
| `export.sh` | 匯出（Pull） | ✅ MD5 檢測 | ✅ 更新 |
| `update.sh` | 單篇上傳（Push） | ❌ 強制覆蓋 | ✅ 更新 |
| `sync.sh` | 批量上傳（Push） | ⏱ 時間比對 | ✅ 更新 |

## 系統優勢

1. **安全性**
   - 衝突檢測防止意外覆蓋
   - 狀態追蹤避免資料遺失

2. **靈活性**
   - 支援單檔或批量操作
   - `--force` 參數提供強制覆蓋選項

3. **相容性**
   - 保留 HackMD 官方 metadata
   - 充分利用平台特性

4. **效率性**
   - 只同步修改的檔案
   - 減少不必要的 API 請求

## 常見問題

### Q: 如何初始化專案？

```bash
# 1. 安裝 hackmd-cli
npm install -g @hackmd/hackmd-cli

# 2. 設定 API token
echo "HMD_API_ACCESS_TOKEN=your_token" > .env

# 3. 匯出所有文章
./scripts/export.sh
```

### Q: 如何處理檔名有特殊字元的文章？

系統會自動處理特殊字元（中文、空格、符號），將不合法字元轉換為底線 `_`。

### Q: 如果 `.sync_state` 檔案遺失怎麼辦？

執行 `./scripts/export.sh` 會重新建立 `.sync_state`，所有檔案會被標記為當前時間同步。

### Q: 如何強制重新同步所有文章？

```bash
./scripts/sync.sh --force
```

## 授權

MIT License

## 貢獻

歡迎提交 Issue 和 Pull Request！
