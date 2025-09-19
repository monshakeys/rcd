# shellcheck shell=zsh
# ==============================================================================
# rcd: 快速切換到多個 repo root 下的 Git 專案
# 功能：
# - 無參數：fzf 選單 (附 tree 預覽)
# - 有參數：fzf 子序列過濾；若無結果，用 agrep 容錯搜尋
# - -l：列出快取清單
# - -c：清快取並重建
# - -h/--help：顯示使用說明
# - JSON 快取 4hr
# ==============================================================================
rcd() {
  # 如果 Homebrew 已安裝 rcd 的話便直接呼叫
  if brew --prefix rcd >/dev/null 2>&1; then
    command rcd "$@"
    return
  fi

  # --- 設定區 ---
  local config_dir="$HOME/.config/rcd"
  local root_config_file="$config_dir/roots"
  local cache_dir="$HOME/.cache"
  local cache_file="$cache_dir/rcd-repos.json"
  local expire=14400  # 4 小時 (秒)

  # 確保快取目錄存在
  mkdir -p "$config_dir"
  mkdir -p "$cache_dir"
  # 檢查並初始化 roots 設定檔
  if [[ ! -f "$root_config_file" ]]; then
    local default_paths=("$HOME/Desktop" "/Volumes/development/projects")
    for path in "${default_paths[@]}"; do
      if [[ -d "$path" ]]; then
        echo "找到預設目錄，已新增: $path" >&2
        echo "$path" >> "$root_config_file"
      fi
    done
    if [[ ! -s "$root_config_file" ]]; then
      echo "警告：未在您的系統上找到任何預設專案目錄。" >&2
      echo "請使用 'rcd --add <path>' 新增您的專案根目錄。" >&2
    fi
  fi
  # 從設定檔讀取路徑到 roots 陣列
  local roots=()
  if [[ -s "$root_config_file" ]]; then
    roots=("${(@f)$(<"$root_config_file")}")
  fi

  # 處理選項
  case "$1" in
    -h|--help)
      # 先讀取一次 roots 清單，以便顯示
      local help_roots=()
      if [[ -f "$root_config_file" ]]; then
        help_roots=("${(@f)$(<"$root_config_file")}")
      fi
      local help_message="
用法: rcd [選項] [關鍵字]

高效直覺的 cd cli 工具，快速切換專案目錄

選項:
  -h, --help    顯示此說明訊息
  -l, --list    列出所有快取中的專案名稱與其短路徑
  -c, --clear   清除快取，下次執行時將強制重建
  --add <path>  新增一個要掃描的專案根目錄
  --remove      以互動方式移除一個專案根目錄

行為:
  rcd           進入 fzf 互動式選單，支援 tree 預覽
  rcd <name>    直接搜尋專案，支援容錯搜尋 (三個字符)

---
設定檔: $root_config_file
快取檔: $cache_file
目前掃描的根目錄:"
      # 動態地將根目錄列表附加到訊息變數的末尾
      for root in "${help_roots[@]}"; do
        help_message+="\n  - $root"
      done
      echo -e "$help_message"
      echo ""
      return 0
      ;;
    --add)
      local new_path="$2"
      if [[ -z "$new_path" ]]; then
        echo "錯誤：請提供要新增的路徑。" >&2
        echo "用法: rcd --add /your/project/path" >&2
        return 1
      fi
      # 將波浪號轉換為家目錄的絕對路徑
      new_path="${new_path/#\~/$HOME}"
      if [[ ! -d "$new_path" ]]; then
        echo "錯誤：路徑 '$new_path' 不存在或不是一個目錄。" >&2
        return 1
      fi
      # 檢查是否已存在，-F 匹配固定字串，-x 匹配整行
      if grep -Fxq "$new_path" "$root_config_file"; then
        echo "路徑 '$new_path' 已存在，無需新增。"
      else
        echo "$new_path" >> "$root_config_file"
        echo "成功新增路徑: $new_path"
        # 新增路徑後，快取已過時，必須清除
        rcd -c
      fi
      return 0
      ;;
    --remove)
      if [[ ! -s "$root_config_file" ]]; then
        echo "設定檔為空，沒有可移除的路徑。"
        return 0
      fi
      echo "請選擇要移除的路徑 (按 ESC 取消):"
      local path_to_remove
      path_to_remove=$(<"$root_config_file" fzf)

      if [[ -n "$path_to_remove" ]]; then
        # 使用 grep -v 過濾掉要刪除的行，並寫入暫存檔
        grep -vFxf <(echo "$path_to_remove") "$root_config_file" > "$root_config_file.tmp"
        mv "$root_config_file.tmp" "$root_config_file"
        echo "成功移除路徑: $path_to_remove"
        # 移除路徑後，快取也必須清除
        rcd -c
      else
        echo "操作已取消。"
      fi
      return 0
      ;;
    -c|--clear)
      rm -f "$cache_file"
      echo "快取已清除，下次查詢將重新建立"
      return 0
      ;;
    -l|--list)
      # 確保快取存在，若不存在則觸發建立
      if [[ ! -f "$cache_file" ]]; then
        rcd "" >/dev/null 2>&1
      fi
      # 使用 jq 提取 name 和 path，再用 awk 格式化輸出
      jq -r '.[] | "\(.name)\t\(.path)"' "$cache_file" | awk -F'\t' '{
        n = split($2, a, "/")
        # 組合最後兩段路徑
        if (n > 2) { short_path = a[n-2] "/" a[n-1] "/" a[n] } else { short_path = $2 }
        printf "%-35s %s\n", $1, short_path
      }'
      return 0
      ;;
  esac

  # 快取檢查與重建
  local needs_rebuild=false
  if [[ ! -f "$cache_file" ]]; then
    needs_rebuild=true
  else
    local last_modified
    # 處理 stat 指令的跨平台差異
    if stat --version >/dev/null 2>&1; then
      last_modified=$(stat -c %Y "$cache_file")
    else # BSD stat
      last_modified=$(stat -f %m "$cache_file")
    fi
    if [[ $(($(date +%s) - last_modified)) -gt $expire ]]; then
      needs_rebuild=true
    fi
  fi

  if [[ "$needs_rebuild" == true ]]; then
    if [ ${#roots[@]} -eq 0 ]; then
      echo "錯誤：沒有設定任何專案根目錄。請使用 'rcd --add <path>' 新增。" >&2
      return 1
    fi
    # 重新建立專案路徑快取列表
    local repos=()
    for root in "${roots[@]}"; do
      if [[ ! -d "$root" ]]; then
        echo "警告：設定的根目錄不存在，已跳過: $root" >&2
        continue # 跳過此次迴圈
      fi
      # 使用 fd 搜尋 .git 目錄，並取得其父目錄
      while IFS= read -r repo_path; do
        repos+=("{\"name\":\"$(basename "$repo_path")\",\"path\":\"$repo_path\"}")
      done < <(fd --hidden --type d --max-depth 4 '^\.git$' "$root" | xargs -n1 dirname)
    done

    if [ ${#repos[@]} -eq 0 ]; then
      echo "警告：在指定的 repo root 中找不到任何 Git 專案" >&2
    fi
    printf '[%s]\n' "$(IFS=,; echo "${repos[*]}")" > "$cache_file.tmp" && mv "$cache_file.tmp" "$cache_file"
  fi

  # --- fzf 處理 ---
  if [[ ! -f "$cache_file" ]] || ! jq . "$cache_file" >/dev/null 2>&1; then
    echo "錯誤：快取檔案不存在或格式錯誤，請嘗試使用 'rcd -c' 清除快取" >&2
    return 1
  fi

  # 準備 fzf 輸入列表，格式為："<對齊的顯示文字>\t<完整路徑>"
  local projects_list
  projects_list=$(jq -r '.[] | "\(.name)\t\(.path)"' "$cache_file" | awk -F'\t' '{
    path = $2
    n = split(path, parts, "/")
    if (n > 2) { short_path = parts[n-2] "/" parts[n-1] "/" parts[n] } else { short_path = path }
    # 格式化輸出：%-35s 是左對齊35個字元寬，後面是短路徑，最後用 tab 分隔出完整路徑
    printf "%-35s %s\t%s\n", $1, short_path, path
  }')

  if [[ -z "$projects_list" ]]; then
    echo "快取為空，請檢查 'roots' 設定或執行 'rcd -c' 清除後重試" >&2
    return 1
  fi

  # 準備 fzf 預覽指令，從 fzf 傳來的整行中提取 tab 後的完整路徑
  local preview_cmd='tree -L 1 -C "$(echo {} | cut -f2 -d$'"'"'\t'"'"')" 2>/dev/null | head -100'
  local target matches selection
  case "$1" in
    "")
      # 無參數 → fzf 選單
      selection=$(echo -n "$projects_list" | fzf --preview="$preview_cmd" --preview-window=right:50%:wrap)
      ;;
    *)
      # 有參數 → fzf 過濾；沒結果再用 ugrep
      matches=$(echo -n "$projects_list" | fzf --filter="$1")
      if [[ -z "$matches" ]]; then
        echo "找不到精確匹配的項目，嘗試使用 ugrep 進行容錯搜尋..." >&2
        # ugrep 只搜尋顯示的部分 (第一欄)，然後將結果 pipe 給 fzf 選擇
        selection=$(echo -n "$projects_list" | ugrep -Z3 -i "$1" | fzf --preview="$preview_cmd" --preview-window=right:50%:wrap)
      else
        # 【修正點】只取 fzf --filter 結果的第一行，避免多路徑問題
        selection=$(echo "$matches" | head -n 1)
      fi
      ;;
  esac

  # 從選擇的行中提取 tab 後面的完整路徑
  target=$(echo "$selection" | cut -f2 -d$'\t')
  if [[ -n "$target" && -d "$target" ]]; then
    cd "$target"
  elif [[ -n "$selection" ]]; then
    # 如果 target 為空或不是目錄，表示選擇被中斷或有誤
    return 1
  fi
}
