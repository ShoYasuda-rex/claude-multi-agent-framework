#!/bin/bash
# ポート競合チェック・解放スクリプト
# 使い方: port-check.sh <port> [kill]
#   port-check.sh 3000        → ポート使用状況を表示
#   port-check.sh 3000 kill   → ポートを使用中のプロセスを全て終了
#
# 出力(JSON風):
#   STATUS=free              → ポート空き
#   STATUS=in_use            → 使用中（PID・プロセス情報を表示）
#   STATUS=freed             → kill実行後に解放確認済み
#   STATUS=kill_failed       → kill実行したが解放されなかった

PORT="$1"
ACTION="${2:-check}"

if [ -z "$PORT" ]; then
  echo "ERROR: ポート番号を指定してください"
  echo "使い方: port-check.sh <port> [kill]"
  exit 1
fi

# OS判定
is_windows() {
  [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]
}

# ポートを使用中のPIDを取得（重複除去）
get_pids() {
  if is_windows; then
    netstat -ano 2>/dev/null | grep "LISTENING" | grep ":${PORT} " | awk '{print $5}' | sort -u
  else
    lsof -ti :"$PORT" 2>/dev/null | sort -u
  fi
}

# PIDからプロセス情報を取得
get_process_info() {
  local pid="$1"
  if is_windows; then
    local cmdline
    cmdline=$(wmic process where "ProcessId=$pid" get CommandLine //FORMAT:LIST 2>/dev/null | grep "CommandLine=" | sed 's/CommandLine=//' | tr -d '\r')
    if [ -z "$cmdline" ]; then
      cmdline="(取得不可)"
    fi
    echo "PID=$pid CMD=$cmdline"
  else
    local info
    info=$(ps -p "$pid" -o pid=,comm=,args= 2>/dev/null | tr -s ' ')
    if [ -z "$info" ]; then
      echo "PID=$pid CMD=(取得不可)"
    else
      echo "PID=$pid CMD=$info"
    fi
  fi
}

# プロセス終了
kill_pid() {
  local pid="$1"
  if is_windows; then
    taskkill //PID "$pid" //F >/dev/null 2>&1
  else
    kill "$pid" 2>/dev/null
  fi
}

# ポート解放確認（最大3回リトライ）
wait_for_release() {
  for i in 1 2 3; do
    sleep 1
    local pids
    pids=$(get_pids)
    if [ -z "$pids" ]; then
      return 0
    fi
  done
  return 1
}

# メイン処理
PIDS=$(get_pids)

if [ -z "$PIDS" ]; then
  echo "STATUS=free"
  echo "PORT=$PORT"
  exit 0
fi

# 使用中のプロセス情報を収集
echo "STATUS=in_use"
echo "PORT=$PORT"
echo "---PROCESSES---"
for pid in $PIDS; do
  get_process_info "$pid"
done

# kill モード
if [ "$ACTION" = "kill" ]; then
  echo "---KILLING---"
  for pid in $PIDS; do
    kill_pid "$pid"
    echo "KILLED=$pid"
  done

  if wait_for_release; then
    echo "STATUS=freed"
  else
    echo "STATUS=kill_failed"
    exit 1
  fi
fi
