#!/bin/bash
# 機密ファイル除外+個別git addスクリプト
# 使い方: git-safe-add.sh
#
# 動作:
#   1. git statusで変更・未追跡ファイルを取得
#   2. 機密・不要ファイルを除外
#   3. 除外したファイルが.gitignoreに未登録なら追記
#   4. 残りを個別にgit add
#
# 出力:
#   ADDED=file1.js,file2.css,...     追加したファイル
#   EXCLUDED=.env,secret.key,...     除外したファイル（理由付き）
#   GITIGNORE_UPDATED=true|false     .gitignoreを更新したか
#   NO_CHANGES=true                  変更なしの場合

# 機密ファイルのパターン（除外+警告）
SECRET_PATTERNS=(
  '.env'
  '.env.*'
  '.dev.vars'
  '*.pem'
  '*.key'
  'credentials.*'
  'secret*'
  '*.p12'
  '*.pfx'
)

# 不要ファイルのパターン（除外のみ）
JUNK_PATTERNS=(
  'node_modules/'
  'dist/'
  'build/'
  '__pycache__/'
  '.next/'
  'vendor/'
  '*.log'
  '.playwright-mcp/'
  '.ruff_cache/'
  '.DS_Store'
  'Thumbs.db'
  '*.pyc'
  '.sass-cache/'
  'coverage/'
  '.nyc_output/'
  'tmp/'
)

# git statusから変更ファイル一覧を取得
get_changed_files() {
  # git status --porcelain のパースは環境依存で不安定なため、
  # 個別コマンドでファイル一覧を取得する
  {
    # 未ステージの変更ファイル
    git diff --name-only 2>/dev/null
    # ステージ済みの変更ファイル
    git diff --cached --name-only 2>/dev/null
    # 未追跡ファイル
    git ls-files --others --exclude-standard 2>/dev/null
  } | sort -u
}

# パターンマッチ判定
matches_pattern() {
  local file="$1"
  local pattern="$2"
  local basename
  basename=$(basename "$file")

  # ディレクトリパターン（末尾/）
  if [[ "$pattern" == */ ]]; then
    local dir_name="${pattern%/}"
    if [[ "$file" == *"$dir_name"/* || "$file" == "$dir_name"/* ]]; then
      return 0
    fi
  # ワイルドカードパターン
  elif [[ "$pattern" == *'*'* ]]; then
    # bashのパターンマッチングを使用
    local regex_pattern="${pattern//\*/.*}"
    if [[ "$basename" =~ ^${regex_pattern}$ ]]; then
      return 0
    fi
  # 完全一致
  else
    if [[ "$basename" == "$pattern" || "$file" == "$pattern" ]]; then
      return 0
    fi
  fi
  return 1
}

# .gitignoreにパターンが存在するか確認
is_in_gitignore() {
  local pattern="$1"
  if [ -f .gitignore ]; then
    grep -qF "$pattern" .gitignore 2>/dev/null
    return $?
  fi
  return 1
}

# メイン処理
FILES=$(get_changed_files)

if [ -z "$FILES" ]; then
  echo "NO_CHANGES=true"
  exit 0
fi

ADDED_FILES=()
EXCLUDED_FILES=()
GITIGNORE_ADDITIONS=()

while IFS= read -r file; do
  [ -z "$file" ] && continue

  excluded=false
  exclude_reason=""
  exclude_pattern=""

  # 機密ファイルチェック
  for pattern in "${SECRET_PATTERNS[@]}"; do
    if matches_pattern "$file" "$pattern"; then
      excluded=true
      exclude_reason="機密"
      exclude_pattern="$pattern"
      break
    fi
  done

  # 不要ファイルチェック
  if [ "$excluded" = false ]; then
    for pattern in "${JUNK_PATTERNS[@]}"; do
      if matches_pattern "$file" "$pattern"; then
        excluded=true
        exclude_reason="不要"
        exclude_pattern="$pattern"
        break
      fi
    done
  fi

  if [ "$excluded" = true ]; then
    EXCLUDED_FILES+=("$file($exclude_reason)")
    # .gitignoreに未登録なら追加候補に
    if ! is_in_gitignore "$exclude_pattern"; then
      GITIGNORE_ADDITIONS+=("$exclude_pattern")
    fi
  else
    git add "$file" 2>/dev/null
    ADDED_FILES+=("$file")
  fi
done <<< "$FILES"

# .gitignore更新
GITIGNORE_UPDATED=false
if [ ${#GITIGNORE_ADDITIONS[@]} -gt 0 ]; then
  # 重複除去
  UNIQUE_ADDITIONS=($(printf '%s\n' "${GITIGNORE_ADDITIONS[@]}" | sort -u))
  if [ ${#UNIQUE_ADDITIONS[@]} -gt 0 ]; then
    # .gitignoreがなければ作成
    [ ! -f .gitignore ] && touch .gitignore
    # 末尾に改行がなければ追加
    [ -s .gitignore ] && [ "$(tail -c1 .gitignore)" != "" ] && echo "" >> .gitignore
    for pattern in "${UNIQUE_ADDITIONS[@]}"; do
      echo "$pattern" >> .gitignore
    done
    git add .gitignore 2>/dev/null
    ADDED_FILES+=(".gitignore")
    GITIGNORE_UPDATED=true
  fi
fi

# 結果出力
if [ ${#ADDED_FILES[@]} -eq 0 ]; then
  echo "NO_CHANGES=true"
  echo "MESSAGE=全ファイルが除外対象でした"
else
  echo "ADDED=$(IFS=,; echo "${ADDED_FILES[*]}")"
fi

if [ ${#EXCLUDED_FILES[@]} -gt 0 ]; then
  echo "EXCLUDED=$(IFS=,; echo "${EXCLUDED_FILES[*]}")"
fi

echo "GITIGNORE_UPDATED=$GITIGNORE_UPDATED"
