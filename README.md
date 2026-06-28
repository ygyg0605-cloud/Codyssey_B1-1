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


설정 파일:

```text
/etc/ssh/sshd_config
```

변경 방법:

```
sudo nano /etc/ssh/sshd_config  #sudo nano로 sshd_config 파일 접속
Port 22 -> Port 20022
PermitRootLogin prohibit-password -> PermitRootLogin no로 수정
sudo sshd -t
sudo systemctl restart ssh   #수정사항 반영
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

방화벽 설정 코드

```text
sudo ufw default deny incoming # 인바운드를 막음(외부에서 내 서버로 접속)
sudo ufw default allow outgoing # 아웃바운드를 허용(내 서버에서 외부로 접속)
sudo ufw allow 20022/tcp or 15034/tcp # 20022 포트, 10534 포트 허용
suo ufw enable # ufw 활성화
sudo ufw status # 상태 확인
```

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

실행 방법

```text
sudo groupadd agent-common & agent-core # 그룹 생성
getent group agent-common & agent-core # 그룹 생성 확인
sudo useradd -m -s /bin/bash agent-admin & agent-dev & agent-test # 사용자 생성 (-m: 홈 디렉토리를 생성, -s /bin/bash: 로그인 시 사용할 쉘을 Bash로 지정)
sudo usermod -aG agent-common,agent-core agent-admin # 사용자를 그룹에 추가
id agent-admin # 사용자 확인
```


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

## 권한 정책 설명

이번 과제에서는 공유 디렉토리와 보안 디렉토리를 분리하기 위해 그룹 권한을 사용하였다.

계정과 그룹 구성은 다음과 같다.

```bash
agent-common: agent-admin, agent-dev, agent-test
agent-core: agent-admin, agent-dev
```

`upload_files`는 세 계정이 모두 사용하는 공유 디렉토리이므로 그룹을 `agent-common`으로 설정하였다.

```bash
sudo chown agent-admin:agent-common /home/agent-admin/agent-app/upload_files
sudo chmod 2770 /home/agent-admin/agent-app/upload_files
```

`api_keys`와 `/var/log/agent-app`은 API 키와 운영 로그가 저장되는 민감한 디렉토리이므로 `agent-core` 그룹만 접근하도록 설정하였다.

```bash
sudo chown agent-admin:agent-core /home/agent-admin/agent-app/api_keys
sudo chmod 2770 /home/agent-admin/agent-app/api_keys

sudo chown agent-admin:agent-core /var/log/agent-app
sudo chmod 2770 /var/log/agent-app
```

`2770`은 소유자와 그룹에게 읽기/쓰기/진입 권한을 주고, 기타 사용자는 차단한다. 앞의 `2`는 `setgid`로, 디렉토리 안에 새 파일이 생성될 때 부모 디렉토리의 그룹을 따라가게 한다.

`monitor.sh`는 과제 요구사항에 따라 소유자를 `agent-dev`, 그룹을 `agent-core`, 권한을 `750`으로 설정하였다.

```bash
sudo chown agent-dev:agent-core /home/agent-admin/agent-app/bin/monitor.sh
sudo chmod 750 /home/agent-admin/agent-app/bin/monitor.sh
```

`750`은 소유자에게 읽기/쓰기/실행 권한, 그룹에게 읽기/실행 권한을 주고, 기타 사용자는 차단한다. 따라서 `agent-dev`는 스크립트를 수정할 수 있고, `agent-admin`은 `agent-core` 그룹에 포함되어 cron으로 실행할 수 있다.

검증 결과 `agent-test`는 `upload_files`에는 파일을 생성할 수 있었지만, `api_keys`에는 접근할 수 없었다. 이를 통해 공유 디렉토리는 `agent-common`에게 열고, 보안 디렉토리는 `agent-core`로 제한하는 권한 정책을 만족

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

## monitor.sh에서 pgrep, ss를 선택한 이유
pgrep - 전체 프로세스 정보를 자세히 보여주는 ps|grep 방식보다 조건에 맞는 프로세스 ID만 찾는 pgrep이 스크립트에서 사용하기 적합하기 때문.
pgrep으로 하면 한 줄에 끝내는데, ps|grep은 전체 목록을 꺼낸 후, 또 특정 프로세스 ID를 입력해야 함.

ss - 현재 열려 있는 포트와 LISTEN 상태를 확인하기 위해 사용. netstart보다 최신 리눅스 환경에서 기본적으로 권장됨.

---

## 로그 용량 관리(10MB/10개) 기능 설명

```
#monitor.sh

Max_SIZE=$((10*1024*1024*)) #1024*1024는 1MB를 byte 단위로 표현한 것. 즉 10MB.
Max_FILES=10 #보관할 로그 파일의 최대 개수 10개

#로그 용량 관리 함수
if [ -f "$LOG_FILE" ]; then #monitor.log 파일의 존재 확인
size=$(stat -c%s "$LOG_FILE") # 현재 로그 파일의 크기를 바이트 단위로 화긴
if [ "$size" -ge "$MAX_SIZE" ]; then # 현재 로그 파일 크기가 10MB 이상인지 비교

 i=$MAX_FILES
      while [ "$i" -ge 1 ]; do
        if [ -f "$LOG_FILE.$i" ]; then
          if [ "$i" -eq "$MAX_FILES" ]; then
            rm -f "$LOG_FILE.$i" # monitor.log.10이 존재하면 삭제(가장 오래된 로그이기 때문)
          else
            mv "$LOG_FILE.$i" "$LOG_FILE.$((i + 1))" # 현재 로그 파일을 monitor.log.1로 이동
          fi
        fi
        i=$((i - 1))
      done
      mv "$LOG_FILE" "$LOG_FILE.1"
    fi
  fi
}
# 로그 파일이 10MB 이상이면 기존 백업 로그를 뒤로 한 칸 씩 이동시킴.

```

## awk 파싱 방식과 로그 포맷 고정 이유

`monitor.sh`에서는 CPU, 메모리, 디스크 사용률을 수집하기 위해 `top`, `free`, `df` 명령어를 사용하였다. 이 명령어들은 사람이 읽기 좋은 형태로 여러 줄과 여러 열을 출력하므로, 스크립트에서는 필요한 숫자만 추출하기 위해 `awk`를 사용하였다.

`awk`는 텍스트를 줄 단위와 열 단위로 나누어 처리할 수 있는 도구이다. 특정 줄을 찾고, 원하는 열만 꺼내거나 계산할 때 적합하다.

### CPU 사용률 추출

```bash
CPU=$(top -bn1 | awk -F',' '/Cpu\(s\)/ {print 100 - $4}' | awk '{printf "%.1f", $1}')
```

`top -bn1`은 CPU 상태를 한 번만 출력한다.

- `-b`: batch 모드로 실행하여 스크립트에서 처리하기 쉽게 출력
- `-n1`: 한 번만 실행하고 종료

`top` 출력에는 다음과 같은 줄이 포함된다.

```text
%Cpu(s):  3.0 us,  1.0 sy,  0.0 ni, 96.0 id,  0.0 wa, ...
```

여기서 `id`는 idle의 의미로, CPU가 쉬고 있는 비율이다. CPU 사용률은 전체 100%에서 idle 비율을 뺀 값으로 계산한다.

```text
CPU 사용률 = 100 - idle 비율
```

`awk -F','`는 쉼표를 기준으로 열을 나누고, `/Cpu\(s\)/`는 `Cpu(s)`가 포함된 줄만 찾는다. 이후 `{print 100 - $4}`로 idle 값을 이용해 CPU 사용률을 계산한다.

마지막 `awk '{printf "%.1f", $1}'`는 결과를 소수점 한 자리로 고정한다.

### 메모리 사용률 추출

```bash
MEM=$(free | awk '/Mem:/ {printf "%.1f", ($3/$2)*100}')
```

`free` 명령어는 메모리 상태를 보여준다.

```text
               total        used        free      shared  buff/cache   available
Mem:         8000000      1200000     3000000      ...
```

`Mem:` 줄에서 `$2`는 전체 메모리, `$3`는 사용 중인 메모리이다. 따라서 메모리 사용률은 다음과 같이 계산한다.

```text
메모리 사용률 = 사용 중인 메모리 / 전체 메모리 * 100
```

`awk '/Mem:/ ...'`는 `Mem:`이 포함된 줄만 찾고, `($3/$2)*100`으로 사용률을 계산한다. `printf "%.1f"`를 사용하여 소수점 한 자리로 출력한다.

### 디스크 사용률 추출

```bash
DISK_USED=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')
```

`df /`는 루트 파티션 `/`의 디스크 사용량을 보여준다.

```text
Filesystem     1K-blocks    Used Available Use% Mounted on
/dev/sda1       50000000 1000000  49000000   2% /
```

두 번째 줄의 다섯 번째 열 `$5`가 디스크 사용률이다.

```text
Use% = 2%
```

스크립트에서는 숫자 비교를 해야 하므로 `%` 기호를 제거한다.

```bash
gsub("%","",$5)
```

즉 `2%`를 `2`로 바꾼다.

- `NR==2`: 두 번째 줄만 처리
- `gsub("%","",$5)`: `%` 기호 제거
- `print $5`: 숫자만 출력

### 로그 포맷 고정 이유

스크립트는 로그를 다음 형식으로 기록한다.

```text
[YYYY-MM-DD HH:MM:SS] PID:... CPU:..% MEM:..% DISK_USED:..%
```

예시:

```text
[2026-05-28 23:38:01] PID:2454 CPU:0.0% MEM:7.1% DISK_USED:1%
```

로그 포맷을 고정한 이유는 운영 중 문제가 발생했을 때 시간순으로 상태를 추적하기 위해서이다. 로그 형식이 매번 달라지면 나중에 `grep`, `awk`, `tail` 같은 명령어로 분석하기 어렵다.

고정된 로그 포맷의 장점은 다음과 같다.

- 장애 발생 시점을 시간 기준으로 추적하기 쉽다.
- PID를 통해 어떤 프로세스를 감시했는지 확인할 수 있다.
- CPU, 메모리, 디스크 사용률을 일정한 이름으로 확인할 수 있다.
- `grep`, `awk` 같은 도구로 필요한 값만 다시 추출하기 쉽다.
- cron으로 반복 실행될 때도 로그 구조가 일정하게 유지된다.

모니터링 로그는 장애 분석과 추세 확인에 사용되는 운영 데이터이므로, 사람이 읽기 쉽고 명령어로 재분석하기 쉬운 고정 포맷으로 남기는 것이 중요하다.

## 경고 항목을 분리한 이유

`monitor.sh`에서는 오류와 경고를 구분하였다.

```bash
오류: agent-app 프로세스 없음, TCP 15034 포트 미열림
경고: 방화벽 비활성화, CPU/MEM/DISK 임계치 초과
```

프로세스가 없거나 포트가 열려 있지 않으면 앱이 정상 서비스 중이라고 보기 어렵기 때문에 `[ERROR]`를 출력하고 종료한다.

```bash
echo "[ERROR] Process is not running"
exit 1
```

반면 방화벽 비활성화나 자원 사용률 초과는 위험 신호이지만 앱이 즉시 중단된 상태는 아니다. CPU나 메모리는 일시적으로 높아질 수 있으므로, 이때마다 스크립트를 종료하면 이후 상태 기록이 끊긴다.

그래서 경고 항목은 `[WARNING]`만 출력하고 스크립트는 계속 실행하여 로그를 남기도록 하였다. 이렇게 하면 운영자가 경고 발생 이후의 CPU, 메모리, 디스크 변화까지 계속 추적할 수 있다.

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

## 12. 기타 질답

# 리다이렉션 '>'와 '>>'의 차이
: '>'는 기존 파일 내용을 지우고 새로 저장. '>>'는 기존 파일 내용을 유지하고 파일 끝에 새 내용을 추가
: 모니토링 로그는 시간 순서대로 계속 쌓여야하기 때문에 '>>'를 사용함.

# 모니터링 대상이 웹 서버로 바뀔 경우 수정할 부분
현재 `monitor.sh`는 `agent-app`을 기준으로 작성되었다. 만약 모니터링 대상이 Nginx 같은 웹 서버로 바뀐다면 다음 항목을 수정해야 한다.

```bash
프로세스 이름
포트 번호
로그 경로
임계값 기준
```

예를 들어 Nginx는 프로세스 이름이 `nginx`이므로 프로세스 확인 부분을 바꿔야 한다.

```bash
APP_NAME="nginx"
pgrep -x nginx
```

포트도 앱 포트인 `15034`가 아니라 웹 서버 포트로 바꿔야 한다.

```bash
PORT=80
PORT=443
```

HTTP는 보통 `80`, HTTPS는 보통 `443` 포트를 사용한다.

로그 경로도 Nginx 기준으로 바뀐다.

```bash
/var/log/nginx/access.log
/var/log/nginx/error.log
```

또한 웹 서버는 접속량에 따라 CPU와 메모리 사용량이 달라질 수 있으므로 임계값도 서비스 특성에 맞게 조정해야 한다.

```bash
CPU > 20%
MEM > 10%
DISK_USED > 80%
```

즉, 모니터링 대상이 바뀌면 이름, 프로세스 확인 방식, 포트 번호, 로그 위치, 자원 임계값을 함께 수정

# 프로세스는 살아있지만 포트가 열리지 않는 경우

가능한 원인은 다음과 같다.

```bash
앱 초기화 오류
AGENT_PORT 환경 변수 설정 오류
다른 프로세스가 같은 포트 사용 중
앱이 0.0.0.0이 아니라 127.0.0.1에만 바인딩됨
키 파일 또는 로그 디렉토리 권한 문제
방화벽 또는 네트워크 설정 문제
```

확인 순서는 다음과 같다.

먼저 프로세스가 실제로 살아있는지 확인한다.

```bash
ps -ef | grep agent-app
```

그다음 포트가 LISTEN 상태인지 확인한다.

```bash
sudo ss -tulnp | grep 15034
```

포트가 보이지 않으면 환경 변수가 올바른지 확인한다.

```bash
echo $AGENT_PORT
echo $AGENT_HOME
echo $AGENT_KEY_PATH
echo $AGENT_LOG_DIR
```

같은 포트를 다른 프로세스가 사용 중인지도 확인한다.

```bash
sudo ss -tulnp | grep 15034
```

마지막으로 키 파일과 로그 디렉토리 권한을 확인한다.

```bash
ls -l /home/agent-admin/agent-app/api_keys/t_secret.key
ls -ld /var/log/agent-app
```

# 로그 급증으로 디스크가 가득 찰 위험이 있을 때 대응
단기 대응은 먼저 디스크 사용량과 큰 로그 파일을 확인하는 것이다.

```bash
df -h
du -sh /var/log/agent-app/*
```

불필요한 오래된 로그는 삭제하고, 보관이 필요한 로그는 압축한다.

```bash
sudo rm /var/log/agent-app/monitor.log.10
gzip /var/log/agent-app/monitor.log.1
```

단, 현재 실행 중인 프로세스가 쓰는 로그 파일을 무작정 삭제하면 공간이 바로 반환되지 않을 수 있으므로 주의해야 한다.

중기 대응은 로그가 계속 쌓여도 디스크를 가득 채우지 않도록 로그 관리 정책을 적용하는 것이다.

```bash
로그 파일 최대 크기 제한
보관 파일 개수 제한
오래된 로그 압축
일정 기간 지난 로그 삭제
logrotate 같은 도구 사용
```
