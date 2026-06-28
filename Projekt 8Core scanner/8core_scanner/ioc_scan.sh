#!/bin/bash
# ==========================================================
# 8Core IOC Scanner v3.1
# Copyright (c) 2026 8Core
# Author: Tomislav Galić / 8Core
# Output: MariaDB + live tail log
# ==========================================================

BASE="/home"
TARGET_TYPE="all"
TARGET_VALUE="/home"

CONFIG="/root/scanner-db.conf"
RUN_LOG="/root/ioc-scan-live.log"

for arg in "$@"; do
  case "$arg" in
    --all)
      BASE="/home"
      TARGET_TYPE="all"
      TARGET_VALUE="/home"
      ;;
    --account=*)
      ACCOUNT="${arg#*=}"
      BASE="/home/$ACCOUNT"
      TARGET_TYPE="account"
      TARGET_VALUE="$ACCOUNT"
      ;;
    --path=*)
      BASE="${arg#*=}"
      TARGET_TYPE="custom_path"
      TARGET_VALUE="$BASE"
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: $0 --all | --account=username | --path=/home/user/path"
      exit 1
      ;;
  esac
done

: > "$RUN_LOG"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$RUN_LOG"
}

die() {
  log "ERROR: $*"
  exit 1
}

[ -f "$CONFIG" ] || die "Missing config: $CONFIG"
source "$CONFIG"

DB_HOST="${DB_HOST//$'\r'/}"
DB_NAME="${DB_NAME//$'\r'/}"
DB_USER="${DB_USER//$'\r'/}"
DB_PASS="${DB_PASS//$'\r'/}"
DB_CHARSET="${DB_CHARSET//$'\r'/}"

[ -d "$BASE" ] || die "Scan path does not exist: $BASE"

case "$BASE" in
  /home|/home/*) ;;
  *) die "Unsafe scan path blocked: $BASE" ;;
esac

mysql_run() {
  mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" --default-character-set="${DB_CHARSET:-utf8mb4}" -N -B -e "$1"
}

sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

guess_source() {
  local file="$1"

  case "$file" in
    *"/wp-content/uploads/"*) echo "wordpress_upload|web_upload" ;;
    *"/wp-content/plugins/"*) echo "wordpress_plugin|plugin" ;;
    *"/wp-content/themes/"*) echo "wordpress_theme|theme" ;;
    *"/administrator/components/"*) echo "joomla_admin_component|component" ;;
    *"/components/"*) echo "joomla_component|component" ;;
    *"/media/com_sppagebuilder/"*) echo "sppagebuilder|builder" ;;
    *"/tmp/"*) echo "tmp_runtime_or_upload|tmp" ;;
    *"/cache/"*) echo "cache_runtime|cache" ;;
    *"/.well-known/"*) echo "well_known|system" ;;
    *) echo "unknown|unknown" ;;
  esac
}

log "8Core IOC Scanner v3.1 started"
log "Base: $BASE"
log "Target type: $TARGET_TYPE"
log "Target value: $TARGET_VALUE"
log "Database: $DB_NAME@$DB_HOST"

mysql_run "SELECT 1;" >/dev/null || die "Database connection failed"

mysql_run "
CREATE TABLE IF NOT EXISTS scans (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  started_at DATETIME NOT NULL,
  finished_at DATETIME NULL,
  base_path VARCHAR(500) NOT NULL,
  target_type VARCHAR(30) NULL,
  target_value VARCHAR(255) NULL,
  files_found INT UNSIGNED DEFAULT 0,
  status VARCHAR(30) DEFAULT 'RUNNING',
  INDEX(status),
  INDEX(started_at),
  INDEX(target_type),
  INDEX(target_value)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS findings (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  scan_id BIGINT UNSIGNED NOT NULL,
  rule_name VARCHAR(150) NOT NULL,
  risk VARCHAR(20) NOT NULL,
  account_name VARCHAR(80) NULL,
  owner_name VARCHAR(80) NULL,
  group_name VARCHAR(80) NULL,
  perms VARCHAR(20) NULL,
  file_size BIGINT UNSIGNED NULL,
  file_name VARCHAR(255) NULL,
  file_ext VARCHAR(30) NULL,
  file_path TEXT NOT NULL,
  relative_path TEXT NULL,
  mtime DATETIME NULL,
  ctime DATETIME NULL,
  birth_time DATETIME NULL,
  detected_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  source_guess VARCHAR(255) NULL,
  source_type VARCHAR(80) NULL,
  sha256 CHAR(64) NULL,
  action_status VARCHAR(40) NOT NULL DEFAULT 'new',
  action_note TEXT NULL,
  action_at DATETIME NULL,
  action_by VARCHAR(80) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX(scan_id),
  INDEX(risk),
  INDEX(rule_name),
  INDEX(account_name),
  INDEX(owner_name),
  INDEX(file_ext),
  INDEX(detected_at),
  INDEX(action_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
" || die "Table creation failed"

mysql_run "
ALTER TABLE scans
  ADD COLUMN IF NOT EXISTS target_type VARCHAR(30) NULL,
  ADD COLUMN IF NOT EXISTS target_value VARCHAR(255) NULL;
" >/dev/null 2>&1

mysql_run "
ALTER TABLE findings
  ADD COLUMN IF NOT EXISTS account_name VARCHAR(80) NULL,
  ADD COLUMN IF NOT EXISTS relative_path TEXT NULL,
  ADD COLUMN IF NOT EXISTS ctime DATETIME NULL,
  ADD COLUMN IF NOT EXISTS birth_time DATETIME NULL,
  ADD COLUMN IF NOT EXISTS detected_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN IF NOT EXISTS source_guess VARCHAR(255) NULL,
  ADD COLUMN IF NOT EXISTS source_type VARCHAR(80) NULL,
  ADD COLUMN IF NOT EXISTS file_ext VARCHAR(30) NULL,
  ADD COLUMN IF NOT EXISTS action_status VARCHAR(40) NOT NULL DEFAULT 'new',
  ADD COLUMN IF NOT EXISTS action_note TEXT NULL,
  ADD COLUMN IF NOT EXISTS action_at DATETIME NULL,
  ADD COLUMN IF NOT EXISTS action_by VARCHAR(80) NULL;
" >/dev/null 2>&1

SCAN_ID=$(mysql_run "
INSERT INTO scans (started_at, base_path, target_type, target_value)
VALUES (NOW(), '$(sql_escape "$BASE")', '$(sql_escape "$TARGET_TYPE")', '$(sql_escape "$TARGET_VALUE")');
SELECT LAST_INSERT_ID();
")

[ -n "$SCAN_ID" ] || die "Could not create scan row"

log "Scan ID: $SCAN_ID"

insert_finding() {
  local rule="$1"
  local risk="$2"
  local file="$3"

  [ -f "$file" ] || return

  local mtime ctime birth owner group size fname perms sha account rel ext source source_guess source_type

  mtime=$(stat -c '%y' "$file" 2>/dev/null | cut -d'.' -f1)
  ctime=$(stat -c '%z' "$file" 2>/dev/null | cut -d'.' -f1)
  birth=$(stat -c '%w' "$file" 2>/dev/null | cut -d'.' -f1)

  [ "$birth" = "-" ] && birth=""

  owner=$(stat -c '%U' "$file" 2>/dev/null)
  group=$(stat -c '%G' "$file" 2>/dev/null)
  size=$(stat -c '%s' "$file" 2>/dev/null)
  perms=$(stat -c '%a' "$file" 2>/dev/null)
  fname=$(basename "$file")

  account=$(echo "$file" | awk -F/ '{print $3}')
  rel="${file#/home/$account/}"

  ext="${fname##*.}"
  [ "$ext" = "$fname" ] && ext=""

  source=$(guess_source "$file")
  source_guess="${source%%|*}"
  source_type="${source##*|}"

  if [ "$risk" = "HIGH" ] || [ "$risk" = "CRITICAL" ]; then
    sha=$(sha256sum "$file" 2>/dev/null | awk '{print $1}')
  else
    sha=""
  fi

  mysql_run "
  INSERT INTO findings
  (
    scan_id, rule_name, risk,
    account_name, owner_name, group_name, perms,
    file_size, file_name, file_ext, file_path, relative_path,
    mtime, ctime, birth_time, detected_at,
    source_guess, source_type, sha256
  )
  VALUES (
    $SCAN_ID,
    '$(sql_escape "$rule")',
    '$(sql_escape "$risk")',
    '$(sql_escape "$account")',
    '$(sql_escape "$owner")',
    '$(sql_escape "$group")',
    '$(sql_escape "$perms")',
    ${size:-0},
    '$(sql_escape "$fname")',
    '$(sql_escape "$ext")',
    '$(sql_escape "$file")',
    '$(sql_escape "$rel")',
    NULLIF('$(sql_escape "$mtime")',''),
    NULLIF('$(sql_escape "$ctime")',''),
    NULLIF('$(sql_escape "$birth")',''),
    NOW(),
    '$(sql_escape "$source_guess")',
    '$(sql_escape "$source_type")',
    '$(sql_escape "$sha")'
  );
  " >/dev/null

  log "FOUND [$risk] $rule :: $file"
}

scan_pattern() {
  local title="$1"
  local risk="$2"
  shift 2

  log "Scanning: $title [$risk]"

  find "$BASE" "$@" 2>/dev/null | while IFS= read -r file; do
    insert_finding "$title" "$risk" "$file"
  done
}

scan_pattern "filefuns.php" "CRITICAL" \
  -type f -name "filefuns.php"

scan_pattern ".sys-* files" "HIGH" \
  -type f -name ".sys-*"

scan_pattern "adman marker txt" "HIGH" \
  -type f -name "adman.*.txt"

scan_pattern "mixed-case PHP extensions" "MEDIUM" \
  -type f \( -name "*.PHP" -o -name "*.Php" -o -name "*.pHp" -o -name "*.PHp" -o -name "*.phP" -o -name "*.pHP" \)

scan_pattern "tmp executable web files" "HIGH" \
  -type f \( -path "*/tmp/*.php" -o -path "*/tmp/*.php5" -o -path "*/tmp/*.phtml" -o -path "*/tmp/*.phar" \)

scan_pattern "suspicious random index.php dirs" "HIGH" \
  -type f -name "index.php" -size +10k \
  -regextype posix-extended \
  -regex '.*/([0-9a-f]{5,6}|[0-9]{5,6})/index\.php$'

scan_pattern "cache.php suspicious locations" "MEDIUM" \
  -type f -name "cache.php"

log "Scanning: known command shell indicators [HIGH]"

find "$BASE" \
  -type f \( -name "*.php" -o -name "*.PHP" -o -name "*.Php" -o -name "*.pHp" -o -name "*.phtml" -o -name "*.php5" -o -name "*.phar" \) \
  -exec grep -IlE "shell_exec|passthru|popen|proc_open|base64_decode|gzinflate|str_rot13|@eval|eval\(" {} \; \
  2>/dev/null | while IFS= read -r file; do
    insert_finding "known command shell indicators" "HIGH" "$file"
  done

COUNT=$(mysql_run "SELECT COUNT(*) FROM findings WHERE scan_id=$SCAN_ID;")

mysql_run "
UPDATE scans
SET finished_at = NOW(),
    files_found = $COUNT,
    status = 'FINISHED'
WHERE id = $SCAN_ID;
" >/dev/null

log "8Core IOC Scanner finished"
log "Scan ID: $SCAN_ID"
log "Findings: $COUNT"
log "Tail: tail -f $RUN_LOG"

echo "DONE scan_id=$SCAN_ID findings=$COUNT"
