# Codyssey_B1-1
코디세이 AI/SW 기초 B1-1 과제

# 리눅스 서버 운영 환경 구축 수행 내역서

## 1. 실습 환경

- OS: Ubuntu 24.04.4 LTS
- 작업 사용자: dbsrl
- 관리자 권한: sudo 사용 가능

확인 명령어:

```bash
lsb_release -a
whoami
sudo -v
```

---

## 2. SSH 보안 설정

### 수행 내용

SSH 접속 포트를 `20022`로 변경하고, root 계정의 원격 SSH 접속을 차단하였다.

방화벽 설정 코드

```text
sudo ufw default deny incoming # 인바운드를 막음(외부에서 내 서버로 접속)
sudo ufw default allow outgoing # 아웃바운드를 허용(내 서버에서 외부로 접속)
sudo ufw allow 20022/tcp or 15034/tcp # 20022 포트, 10534 포트 허용
suo ufw enable # ufw 활성화
sudo ufw status # 상태 확인
```

설정 파일:

```text
/etc/ssh/sshd_config
```

확인 명령어:

```bash
sudo grep -E '^(Port|PermitRootLogin)' /etc/ssh/sshd_config
systemctl status ssh
sudo ss -tulnp | grep 20022
```

확인 결과:

```text
Port 20022
PermitRootLogin no
```

```text
SSH 서비스 active (running)
sshd가 0.0.0.0:20022 및 [::]:20022에서 LISTEN 상태
```

### 설명

SSH 기본 포트인 22번은 자동 공격 대상이 되기 쉽기 때문에 포트를 변경하였다. 또한 root 원격 접속을 차단하여 최고 관리자 계정이 직접 노출되는 위험을 줄였다.

---

## 3. 방화벽 설정

### 수행 내용

UFW를 사용하여 방화벽을 활성화하고, 인바운드 허용 포트를 `20022/tcp`, `15034/tcp`로 제한하였다.

확인 명령어:

```bash
sudo ufw status
```

확인 결과:

```text
Status: active

To                         Action      From
--                         ------      ----
20022/tcp                  ALLOW       Anywhere
15034/tcp                  ALLOW       Anywhere
20022/tcp (v6)             ALLOW       Anywhere (v6)
15034/tcp (v6)             ALLOW       Anywhere (v6)
```

### 설명

필요한 포트만 허용하면 외부에서 접근 가능한 통로가 줄어들어 서버 공격 가능성을 낮출 수 있다.

---

## 4. 계정 및 그룹 생성

### 생성 계정

```text
agent-admin
agent-dev
agent-test
```

### 생성 그룹

```text
agent-common
agent-core
```

### 그룹 구성

```text
agent-admin: agent-common, agent-core
agent-dev: agent-common, agent-core
agent-test: agent-common
```

확인 명령어:

```bash
id agent-admin
id agent-dev
id agent-test
```

확인 결과:

```text
uid=1001(agent-admin) gid=1004(agent-admin) groups=1004(agent-admin),1002(agent-common),1003(agent-core)
uid=1002(agent-dev) gid=1005(agent-dev) groups=1005(agent-dev),1002(agent-common),1003(agent-core)
uid=1003(agent-test) gid=1006(agent-test) groups=1006(agent-test),1002(agent-common)
```

### 설명

`agent-common`은 공용 작업을 위한 그룹이고, `agent-core`는 민감한 파일과 로그에 접근할 수 있는 핵심 그룹이다. `agent-test`는 민감한 파일에 접근하지 못하도록 `agent-core`에서 제외하였다.

---

## 5. 디렉토리 구조 및 권한 설정

### 디렉토리 구조

```text
/home/agent-admin/agent-app
/home/agent-admin/agent-app/upload_files
/home/agent-admin/agent-app/api_keys
/var/log/agent-app
```

확인 명령어:

```bash
sudo ls -ld /home/agent-admin /home/agent-admin/agent-app /home/agent-admin/agent-app/upload_files /home/agent-admin/agent-app/api_keys /var/log/agent-app
```

확인 결과:

```text
drwx--x--- 4 agent-admin agent-common 4096 May 28 23:20 /home/agent-admin
drwxr-s--- 5 agent-admin agent-common 4096 May 28 23:16 /home/agent-admin/agent-app
drwxrws--- 2 agent-admin agent-core   4096 May 28 22:30 /home/agent-admin/agent-app/api_keys
drwxrws--- 2 agent-admin agent-common 4096 May 28 22:22 /home/agent-admin/agent-app/upload_files
drwxrws--- 2 agent-admin agent-core   4096 May 28 23:20 /var/log/agent-app
```

### 권한 정책

```text
upload_files:
- group = agent-common
- agent-admin, agent-dev, agent-test 읽기/쓰기 가능

api_keys:
- group = agent-core
- agent-admin, agent-dev만 읽기/쓰기 가능
- agent-test 접근 불가

/var/log/agent-app:
- group = agent-core
- agent-admin, agent-dev만 읽기/쓰기 가능
```

---

## 6. 환경 변수 설정

설정 파일:

```text
/etc/profile.d/agent-app.sh
```

설정 내용:

```bash
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
export AGENT_LOG_DIR=/var/log/agent-app
```

확인 명령어:

```bash
source /etc/profile.d/agent-app.sh
echo $AGENT_HOME
echo $AGENT_PORT
echo $AGENT_UPLOAD_DIR
echo $AGENT_KEY_PATH
echo $AGENT_LOG_DIR
```

확인 결과:

```text
/home/agent-admin/agent-app
15034
/home/agent-admin/agent-app/upload_files
/home/agent-admin/agent-app/api_keys/t_secret.key
/var/log/agent-app
```

---

## 7. 키 파일 생성

### 수행 내용

앱 실행에 필요한 키 파일을 생성하였다.

경로:

```text
/home/agent-admin/agent-app/api_keys/t_secret.key
```

내용:

```text
agent_api_key_test
```

권한:

```text
-rw-rw---- 1 agent-admin agent-core ... t_secret.key
```

검증 결과:

```text
agent-dev는 키 파일 읽기 가능
agent-test는 Permission denied로 접근 불가
```

---

## 8. 애플리케이션 실행 확인

### 실행 계정

```text
agent-admin
```

### 실행 명령어

```bash
sudo -u agent-admin env \
AGENT_HOME=/home/agent-admin/agent-app \
AGENT_PORT=15034 \
AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files \
AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys/t_secret.key \
AGENT_LOG_DIR=/var/log/agent-app \
/home/agent-admin/agent-app/agent-app
```

### 실행 결과

```text
>>> Starting Agent Boot Sequence...
[1/5] Checking User Account               [OK]
 ... Running as service user 'agent-admin' (uid=1001)
[2/5] Verifying Environment Variables     [OK]
 ... All required Envs correct
[3/5] Checking Required Files             [OK]
 ... Verified 'secret.key' with correct key string.
[4/5] Checking Port Availability          [OK]
 ... Port 15034 is available.
[5/5] Verifying Log Permission            [OK]
 ... Log directory is writable: /var/log/agent-app
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
Agent listening at port 15034
```

### 포트 확인

확인 명령어:

```bash
sudo ss -tulnp | grep 15034
```

확인 결과:

```text
tcp LISTEN 0 1 0.0.0.0:15034 0.0.0.0:* users:(("agent-app",pid=2455,fd=4))
```

---

## 9. monitor.sh 구현

### 파일 위치

```text
/home/agent-admin/agent-app/bin/monitor.sh
```

### 파일 권한

확인 명령어:

```bash
sudo ls -l /home/agent-admin/agent-app/bin/monitor.sh
```

확인 결과:

```text
-rwxr-x--- 1 agent-dev agent-core 2146 May 28 23:26 /home/agent-admin/agent-app/bin/monitor.sh
```

### 기능

```text
- agent-app 프로세스 실행 여부 확인
- TCP 15034 포트 LISTEN 상태 확인
- UFW 또는 firewalld 활성화 상태 확인
- CPU 사용률 수집
- 메모리 사용률 수집
- 루트 디스크 사용률 수집
- CPU > 20%, MEM > 10%, DISK_USED > 80%일 때 WARNING 출력
- /var/log/agent-app/monitor.log에 상태 기록
- monitor.log가 10MB 이상이면 최대 10개 파일로 로그 회전
```

monitor.sh 실행 권한 설정

```text
sudo chown agent-dev:agent-core /home/agent-admin/agent-app/bin/monitor.sh
sudo chmod 750 /home/agent-admin/agent-app/bin/monitor.sh
```

### monitor.sh 소스코드

```bash
#!/bin/bash

AGENT_HOME="${AGENT_HOME:-/home/agent-admin/agent-app}"
AGENT_PORT="${AGENT_PORT:-15034}"
AGENT_LOG_DIR="${AGENT_LOG_DIR:-/var/log/agent-app}"
LOG_FILE="$AGENT_LOG_DIR/monitor.log"

APP_NAME="agent-app"
MAX_SIZE=$((10 * 1024 * 1024))
MAX_FILES=10

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

rotate_logs() {
  if [ -f "$LOG_FILE" ]; then
    size=$(stat -c%s "$LOG_FILE")
    if [ "$size" -ge "$MAX_SIZE" ]; then
      i=$MAX_FILES
      while [ "$i" -ge 1 ]; do
        if [ -f "$LOG_FILE.$i" ]; then
          if [ "$i" -eq "$MAX_FILES" ]; then
            rm -f "$LOG_FILE.$i"
          else
            mv "$LOG_FILE.$i" "$LOG_FILE.$((i + 1))"
          fi
        fi
        i=$((i - 1))
      done
      mv "$LOG_FILE" "$LOG_FILE.1"
    fi
  fi
}

PID=$(pgrep -u agent-admin -f "$AGENT_HOME/$APP_NAME" | head -n 1)

if [ -z "$PID" ]; then
  echo "[$(timestamp)] [ERROR] Process $APP_NAME is not running"
  exit 1
fi

if ! ss -tuln | grep -q ":$AGENT_PORT "; then
  echo "[$(timestamp)] [ERROR] TCP port $AGENT_PORT is not LISTEN"
  exit 1
fi

if command -v ufw >/dev/null 2>&1; then
  if ! systemctl is-active ufw >/dev/null 2>&1; then
    echo "[$(timestamp)] [WARNING] UFW firewall is inactive"
  fi
elif command -v firewall-cmd >/dev/null 2>&1; then
  if ! firewall-cmd --state 2>/dev/null | grep -q "running"; then
    echo "[$(timestamp)] [WARNING] firewalld is inactive"
  fi
else
  echo "[$(timestamp)] [WARNING] No supported firewall tool found"
fi

CPU=$(top -bn1 | awk -F',' '/Cpu\(s\)/ {print 100 - $4}' | awk '{printf "%.1f", $1}')
MEM=$(free | awk '/Mem:/ {printf "%.1f", ($3/$2)*100}')
DISK_USED=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')

if awk -v value="$CPU" 'BEGIN { exit !(value > 20) }'; then
  echo "[$(timestamp)] [WARNING] CPU usage is high: ${CPU}%"
fi

if awk -v value="$MEM" 'BEGIN { exit !(value > 10) }'; then
  echo "[$(timestamp)] [WARNING] Memory usage is high: ${MEM}%"
fi

if [ "$DISK_USED" -gt 80 ]; then
  echo "[$(timestamp)] [WARNING] Disk usage is high: ${DISK_USED}%"
fi

rotate_logs

echo "[$(timestamp)] PID:$PID CPU:${CPU}% MEM:${MEM}% DISK_USED:${DISK_USED}%" >> "$LOG_FILE"
```

### 실행 확인

실행 명령어:

```bash
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh
```

로그 확인 명령어:

```bash
sudo tail -n 5 /var/log/agent-app/monitor.log
```

확인 결과:

```text
[2026-05-28 23:27:56] PID:2454 CPU:1.2% MEM:9.1% DISK_USED:1%
[2026-05-28 23:27:56] PID:2454 CPU:0.0% MEM:9.1% DISK_USED:1%
[2026-05-28 23:27:56] PID:2454 CPU:1.2% MEM:9.0% DISK_USED:1%
[2026-05-28 23:37:01] PID:2454 CPU:9.5% MEM:10.3% DISK_USED:1%
[2026-05-28 23:38:01] PID:2454 CPU:0.0% MEM:7.1% DISK_USED:1%
```

---

## 10. cron 자동 실행 등록

### 수행 내용

`agent-admin` 계정의 crontab에 `monitor.sh`를 매분 실행하도록 등록하였다.

등록 명령어:

```bash
echo "* * * * * /home/agent-admin/agent-app/bin/monitor.sh" | sudo crontab -u agent-admin -
```

확인 명령어:

```bash
sudo crontab -u agent-admin -l
```

확인 결과:

```text
* * * * * /home/agent-admin/agent-app/bin/monitor.sh
```

### 자동 실행 확인

`monitor.log`에서 1분 간격으로 로그가 추가되는 것을 확인하였다.

확인 결과:

```text
[2026-05-28 23:37:01] PID:2454 CPU:9.5% MEM:10.3% DISK_USED:1%
[2026-05-28 23:38:01] PID:2454 CPU:0.0% MEM:7.1% DISK_USED:1%
```

---

## 11. 최종 체크리스트

- [x] SSH 포트 20022 변경
- [x] Root 원격 접속 차단
- [x] UFW 활성화
- [x] 20022/tcp 허용
- [x] 15034/tcp 허용
- [x] agent-admin 계정 생성
- [x] agent-dev 계정 생성
- [x] agent-test 계정 생성
- [x] agent-common 그룹 생성 및 사용자 배치
- [x] agent-core 그룹 생성 및 사용자 배치
- [x] AGENT_HOME 디렉토리 생성
- [x] upload_files 권한 설정
- [x] api_keys 권한 설정
- [x] /var/log/agent-app 권한 설정
- [x] 키 파일 t_secret.key 생성
- [x] 환경 변수 설정
- [x] 앱 Boot Sequence 5단계 [OK] 확인
- [x] Agent READY 확인
- [x] TCP 15034 LISTEN 확인
- [x] monitor.sh 작성
- [x] monitor.sh 권한 750 설정
- [x] monitor.log 누적 기록 확인
- [x] agent-admin crontab 매분 실행 등록
- [x] 1분 후 monitor.log 자동 증가 확인
