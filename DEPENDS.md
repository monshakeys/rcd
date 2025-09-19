# 依賴管理規格文件 (DEPENDS.md)

本文件定義 RCD 專案的第三方依賴實作規格。

## 📋 依賴清單

- fzf - Download & Cache
- fd - Download & Cache
- tree - Download & Cache
- ugrep - Download & Cache
- jq - Rust Crate (`serde_json`)

## 🔧 Download & Cache 實作規格

### 核心實作架構

```rust
pub struct ToolManager {
    cache_dir: PathBuf,        // ~/.rcd/tools/
    tools_config: ToolsConfig, // 版本和 checksum 配置
}

pub struct ToolInfo {
    name: String,
    version: String,
    download_urls: HashMap<Platform, String>,
    checksums: HashMap<Platform, String>,
    executable_name: String,
}
```

## 🛠️ 各工具詳細規格

### 1. fzf - 模糊搜索互動選單

版本鎖定: `v0.46.1`
下載來源: `https://github.com/junegunn/fzf/releases/`

平台支援:
```toml
[tools.fzf]
version = "0.46.1"

[tools.fzf.platforms.macos-x64]
url = "https://github.com/junegunn/fzf/releases/download/0.46.1/fzf-0.46.1-darwin_amd64.zip"
checksum = "sha256:abc123..."
executable = "fzf"

[tools.fzf.platforms.macos-arm64]
url = "https://github.com/junegunn/fzf/releases/download/0.46.1/fzf-0.46.1-darwin_arm64.zip"
checksum = "sha256:def456..."
executable = "fzf"

[tools.fzf.platforms.linux-x64]
url = "https://github.com/junegunn/fzf/releases/download/0.46.1/fzf-0.46.1-linux_amd64.tar.gz"
checksum = "sha256:ghi789..."
executable = "fzf"

[tools.fzf.platforms.windows-x64]
url = "https://github.com/junegunn/fzf/releases/download/0.46.1/fzf-0.46.1-windows_amd64.zip"
checksum = "sha256:jkl012..."
executable = "fzf.exe"
```

### 2. fd - 快速檔案搜索

版本鎖定: `v8.7.1`
下載來源: `https://github.com/sharkdp/fd/releases/`

平台支援:
```toml
[tools.fd]
version = "8.7.1"

[tools.fd.platforms.macos-x64]
url = "https://github.com/sharkdp/fd/releases/download/v8.7.1/fd-v8.7.1-x86_64-apple-darwin.tar.gz"
checksum = "sha256:mno345..."
executable = "fd"

[tools.fd.platforms.macos-arm64]
url = "https://github.com/sharkdp/fd/releases/download/v8.7.1/fd-v8.7.1-aarch64-apple-darwin.tar.gz"
checksum = "sha256:pqr678..."
executable = "fd"
```

### 3. tree - 目錄結構顯示

版本鎖定: `v2.1.1`
下載來源: 編譯自源碼或使用預編譯包

特殊處理: tree 沒有官方 GitHub releases，需要：
1. 從 Homebrew 公式獲取源碼
2. 或使用各平台的預編譯包
3. 提供內建簡化實作作為備援

### 4. ugrep - 容錯搜尋

版本鎖定: `v4.3.2`
下載來源: `https://github.com/Genivia/ugrep/releases/`

備援策略: 如果下載失敗，使用內建的 `strsim` + `fuzzy-matcher` 實作

### 5. jq → serde_json (Rust Crate)

使用 Rust crate 替代外部工具：
```toml
[dependencies]
serde_json = "1.0"
```

## 🏗️ 實作技術細節

### 快取目錄結構
```
~/.rcd/
├── tools/                 # 工具快取目錄
│   ├── fzf-0.46.1         # 版本化目錄
│   │   └── fzf*           # 可執行檔
│   ├── fd-8.7.1/
│   │   └── fd*
│   ├── tree-2.1.1/
│   │   └── tree*
│   └── ugrep-4.3.2/
│       └── ugrep*
├── tools.lock             # 工具版本鎖定檔
└── config.toml            # 用戶配置
```

### 下載流程
1. **檢查快取**: 檢查 `~/.rcd/tools/{tool}-{version}/` 是否存在
2. **平台偵測**: 偵測當前作業系統和架構
3. **下載檔案**: 從 GitHub Releases 下載對應平台版本
4. **驗證完整性**: SHA256 checksum 驗證
5. **解壓安裝**: 解壓到版本化目錄
6. **權限設定**: 設定可執行權限 (Unix 系統)
7. **記錄版本**: 更新 `tools.lock`

### 錯誤處理 (Fail Fast)
```rust
pub enum ToolError {
    DownloadFailed(String),
    ChecksumMismatch { expected: String, actual: String },
    ExtractionFailed(String),
    UnsupportedPlatform(String),
    NetworkError(String),
}
```

失敗情況:
- 下載失敗 → 立即報錯，提供手動安裝指引
- Checksum 不符 → 立即報錯，安全考量
- 平台不支援 → 立即報錯，提供支援平台清單
- 網路錯誤 → 立即報錯，建議檢查網路連線

### 版本管理
- 工具下載後不自動更新
- 版本完全鎖定在配置檔中
- 用戶如需更新，需要手動升級 RCD 版本
- 保證穩定性和可重現性

## 🌍 平台兼容性

### 支援平台
- ✅ macOS x64 (Intel)
- ✅ macOS ARM64 (Apple Silicon)
- ✅ Linux x64 (GNU libc)
- ✅ Windows x64

### 不支援平台
- ❌ Linux ARM64
- ❌ 32-bit 系統
- ❌ musl Linux

---

規格版本: v1.0