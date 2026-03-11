#!/bin/bash
# GitHub Actions 完了待ち+結果取得スクリプト
# 使い方: gh-actions-wait.sh <branch>
#
# 出力:
#   RUN_ID=123456
#   STATUS=completed
#   CONCLUSION=success|failure|cancelled
#   FAILED_LOG=（failure時のみ、エラーログ）

BRANCH="$1"

if [ -z "$BRANCH" ]; then
  echo "ERROR: ブランチ名を指定してください"
  exit 1
fi

# gh CLI の存在確認
if ! command -v gh &>/dev/null; then
  echo "STATUS=no_gh_cli"
  echo "MESSAGE=gh CLIが未インストールです。GitHub Actionsの結果はGitHubで確認してください。"
  exit 0
fi

# 認証確認
if ! gh auth status &>/dev/null 2>&1; then
  echo "STATUS=not_authenticated"
  echo "MESSAGE=gh CLIが未認証です。'gh auth login' を実行してください。"
  exit 0
fi

# 最新のrunを検出（pushしたブランチと一致するまで最大30秒待つ）
RUN_JSON=""
for i in $(seq 1 6); do
  RUN_JSON=$(gh run list --limit 1 --branch "$BRANCH" --json databaseId,status,conclusion,name,headBranch 2>/dev/null)

  # JSONが取得できて、ブランチが一致するか確認
  if [ -n "$RUN_JSON" ] && [ "$RUN_JSON" != "[]" ]; then
    HEAD=$(echo "$RUN_JSON" | grep -o '"headBranch":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ "$HEAD" = "$BRANCH" ]; then
      break
    fi
  fi

  if [ "$i" -lt 6 ]; then
    sleep 5
  fi
done

if [ -z "$RUN_JSON" ] || [ "$RUN_JSON" = "[]" ]; then
  echo "STATUS=no_run_found"
  echo "MESSAGE=ブランチ '$BRANCH' のワークフロー実行が見つかりませんでした。"
  exit 0
fi

# run情報をパース
RUN_ID=$(echo "$RUN_JSON" | grep -o '"databaseId":[0-9]*' | head -1 | cut -d: -f2)
STATUS=$(echo "$RUN_JSON" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
CONCLUSION=$(echo "$RUN_JSON" | grep -o '"conclusion":"[^"]*"' | head -1 | cut -d'"' -f4)
NAME=$(echo "$RUN_JSON" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)

echo "RUN_ID=$RUN_ID"
echo "NAME=$NAME"

# in_progress / queued の場合は完了まで待機
if [ "$STATUS" = "in_progress" ] || [ "$STATUS" = "queued" ]; then
  echo "WAITING=true"
  gh run watch "$RUN_ID" --exit-status >/dev/null 2>&1
  # watch後に再取得
  RUN_JSON=$(gh run list --limit 1 --branch "$BRANCH" --json databaseId,status,conclusion 2>/dev/null)
  STATUS=$(echo "$RUN_JSON" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
  CONCLUSION=$(echo "$RUN_JSON" | grep -o '"conclusion":"[^"]*"' | head -1 | cut -d'"' -f4)
fi

echo "STATUS=$STATUS"
echo "CONCLUSION=$CONCLUSION"

# failure時はエラーログを取得
if [ "$CONCLUSION" = "failure" ]; then
  echo "---FAILED_LOG---"
  gh run view "$RUN_ID" --log-failed 2>/dev/null | tail -50
fi
