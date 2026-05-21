#!/bin/bash

NQ_ROOT="${NQ_ROOT:-/opt/nodequality}"
NQ_COMMON_DIR="${NQ_COMMON_DIR:-$NQ_ROOT/common}"
NQ_MODULES_DIR="${NQ_MODULES_DIR:-$NQ_ROOT/modules}"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

Font_B="\033[1m"
Font_D="\033[2m"
Font_I="\033[3m"
Font_U="\033[4m"
Font_Black="\033[30m"
Font_Red="\033[31m"
Font_Green="\033[32m"
Font_Yellow="\033[33m"
Font_Blue="\033[34m"
Font_Purple="\033[35m"
Font_Cyan="\033[36m"
Font_White="\033[37m"
Back_Black="\033[40m"
Back_Red="\033[41m"
Back_Green="\033[42m"
Back_Yellow="\033[43m"
Back_Blue="\033[44m"
Back_Purple="\033[45m"
Back_Cyan="\033[46m"
Back_White="\033[47m"
Font_Suffix="\033[0m"
Font_LineClear="\033[2K"

nq_log() {
  local level="$1"
  shift
  printf '[%s] %s\n' "$level" "$*"
}

nq_info() {
  nq_log INFO "$@"
}

nq_warn() {
  nq_log WARN "$@" >&2
}

nq_error() {
  nq_log ERROR "$@" >&2
}

nq_has_command() {
  command -v "$1" >/dev/null 2>&1
}

nq_require_command() {
  local command_name
  for command_name in "$@"; do
    if ! nq_has_command "$command_name"; then
      nq_error "Missing required command: $command_name"
      return 1
    fi
  done
}

nq_check_dependencies() {
  local message="${1:-脚本不会执行包管理器命令，请参考 README 的包管理器安装指南后重试。}"
  shift || true
  local -a missing_deps=()
  local dep

  for dep in "$@"; do
    command -v "$dep" >/dev/null 2>&1 || missing_deps+=("$dep")
  done

  if ((${#missing_deps[@]} > 0)); then
    echo -e "${Font_B}${Font_Red}缺少必要依赖：${missing_deps[*]}${Font_Suffix}"
    echo "$message"
    exit 1
  fi
}

show_progress_bar() {
  show_progress_bar_ "$@" 1>&2
}

show_progress_bar_() {
  local bar="\u280B\u2819\u2839\u2838\u283C\u2834\u2826\u2827\u2807\u280F"
  local n=${#bar}
  local tmpinfo=""
  local tmplen="${2:-0}"
  local last_stage=""
  local upload_seen=0

  while sleep 0.1; do
    if ! kill -0 "${main_pid:-$$}" 2>/dev/null; then
      echo -ne ""
      exit
    fi

    if ((upload_seen == 0)) && [[ -n ${3:-} ]]; then
      while IFS= read -r -t 0.05 line; do
        [[ -z $line ]] && continue
        if [[ $3 -eq 1 ]]; then
          if [[ $line == *"Uploading results"* ]]; then
            upload_seen=1
            break
          fi
          case "$line" in
            *"Running"*) last_stage="${line#"${line%%[![:space:]]*}"}" ;;
          esac
        elif [[ $3 -eq 2 ]]; then
          last_stage="$line"
        fi
      done
    fi

    if ((upload_seen == 0)) && [[ -n $last_stage ]]; then
      tmpinfo="$last_stage"
    else
      tmpinfo=""
    fi

    tmplen=$((${2:-0} - ${#tmpinfo}))
    ((tmplen < 0)) && tmplen=0
    echo -ne "\r$Font_Cyan$Font_B[${IP:-}]# $1$tmpinfo$Font_Cyan$Font_B$(printf '%*s' "$tmplen" '' | tr ' ' '.') ${bar:ibar++*6%n:6} $(printf '%02d%%' "${ibar_step:-0}") $Font_Suffix"
  done
}

kill_progress_bar() {
  kill "$bar_pid" 2>/dev/null && echo -ne "\r"
}

adapt_locale() {
  local ifunicode
  ifunicode=$(printf '\u2800')
  [[ ${#ifunicode} -gt 3 ]] && export LC_CTYPE=en_US.UTF-8 2>/dev/null
}

adaptoslocale() {
  adapt_locale
}

is_valid_ipv4() {
  local ip=$1
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    IFS='.' read -r -a octets <<<"$ip"
    for octet in "${octets[@]}"; do
      if ((octet < 0 || octet > 255)); then
        IPV4work=0
        return 1
      fi
    done
    IPV4work=1
    return 0
  fi

  IPV4work=0
  return 1
}

get_ipv4() {
  local response
  local timeout="${NQ_IP_LOOKUP_TIMEOUT:-2}"
  IPV4=""
  local API_NET=("myip.check.place" "ip.sb" "ping0.cc" "icanhazip.com" "api64.ipify.org" "ifconfig.co" "ident.me")
  for p in "${API_NET[@]}"; do
    response=$(curl ${CurlARG:-} -s4 --max-time "$timeout" "$p")
    if [[ $? -eq 0 && ! $response =~ error && -n $response ]]; then
      IPV4="$response"
      break
    fi
  done
}

hide_ipv4() {
  if [[ -n $1 ]]; then
    IFS='.' read -r -a ip_parts <<<"$1"
    IPhide="${ip_parts[0]}.${ip_parts[1]}.*.*"
  else
    IPhide=""
  fi
}

is_valid_ipv6() {
  local ip=$1
  if [[ $ip =~ ^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$ || $ip =~ ^([0-9a-fA-F]{1,4}:){1,7}:$ || $ip =~ ^:([0-9a-fA-F]{1,4}:){1,7}$ || $ip =~ ^([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}$ || $ip =~ ^([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}$ || $ip =~ ^([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}$ || $ip =~ ^([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}$ || $ip =~ ^([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}$ || $ip =~ ^[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})$ || $ip =~ ^:((:[0-9a-fA-F]{1,4}){1,7}|:)$ || $ip =~ ^fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}$ || $ip =~ ^::(ffff(:0{1,4}){0,1}:){0,1}(([0-9]{1,3}\.){3}[0-9]{1,3})$ || $ip =~ ^([0-9a-fA-F]{1,4}:){1,4}:(([0-9]{1,3}\.){3}[0-9]{1,3})$ ]]; then
    IPV6work=1
    return 0
  fi

  IPV6work=0
  return 1
}

get_ipv6() {
  local response
  local timeout="${NQ_IP_LOOKUP_TIMEOUT:-2}"
  IPV6=""
  local API_NET=("myip.check.place" "ip.sb" "ping0.cc" "icanhazip.com" "api64.ipify.org" "ifconfig.co" "ident.me")
  for p in "${API_NET[@]}"; do
    response=$(curl ${CurlARG:-} -s6k --max-time "$timeout" "$p")
    if [[ $? -eq 0 && ! $response =~ error && -n $response ]]; then
      IPV6="$response"
      break
    fi
  done
}

hide_ipv6() {
  if [[ -n $1 ]]; then
    local expanded_ip
    expanded_ip=$(echo "$1" | sed 's/::/:0000:0000:0000:0000:0000:0000:0000:0000:/g' | cut -d ':' -f1-8)
    IFS=':' read -r -a ip_parts <<<"$expanded_ip"
    while [ ${#ip_parts[@]} -lt 8 ]; do
      ip_parts+=(0000)
    done
    IPhide="${ip_parts[0]:-0}:${ip_parts[1]:-0}:${ip_parts[2]:-0}:*:*:*:*:*"
    IPhide=$(echo "$IPhide" | sed 's/:0\{1,\}/:/g' | sed 's/::\+/:/g')
  else
    IPhide=""
  fi
}

calculate_display_width() {
  local string="$1"
  local length=0
  local char
  local i
  for ((i = 0; i < ${#string}; i++)); do
    char=$(echo "$string" | od -An -N1 -tx1 -j $((i)) | tr -d ' ')
    if [ "$(printf '%d\n' 0x$char)" -gt 127 ]; then
      length=$((length + 2))
      i=$((i + 1))
    else
      length=$((length + 1))
    fi
  done
  echo "$length"
}

calc_padding() {
  local input_text="$1"
  local total_width=$2
  local title_length
  local left_padding
  title_length=$(calculate_display_width "$input_text")
  left_padding=$(((total_width - title_length) / 2))
  if [[ $left_padding -gt 0 ]]; then
    PADDING=$(printf '%*s' "$left_padding")
  else
    PADDING=""
  fi
}

clean_ansi() {
  local input="$1"
  echo -e "$input" | sed 's/\x1b\[[0-9;]*[mGKHF]//g'
}

generate_random_user_agent() {
  local browsers_keys=("${!browsers[@]}")
  local random_browser_index=$((RANDOM % ${#browsers_keys[@]}))
  local browser="${browsers_keys[random_browser_index]}"
  local versions
  local version

  case "$browser" in
    Chrome)
      versions=(${browsers[Chrome]})
      version="${versions[RANDOM % ${#versions[@]}]}"
      UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$version Safari/537.36"
      ;;
    Firefox)
      versions=(${browsers[Firefox]})
      version="${versions[RANDOM % ${#versions[@]}]}"
      UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:$version) Gecko/20100101 Firefox/$version"
      ;;
  esac
}

nq_module_entry() {
  local module="$1"

  case "$module" in
    hardware)
      printf '%s\n' "$NQ_MODULES_DIR/HardwareQuality/hardware.sh"
      ;;
    ip)
      printf '%s\n' "$NQ_MODULES_DIR/IPQuality/ip.sh"
      ;;
    net)
      printf '%s\n' "$NQ_MODULES_DIR/NetQuality/net.sh"
      ;;
    *)
      return 1
      ;;
  esac
}

nq_run_module() {
  local module="$1"
  shift
  local entry

  entry="$(nq_module_entry "$module")" || {
    nq_error "Unknown module: $module"
    return 127
  }

  if [[ ! -f "$entry" ]]; then
    nq_error "Module entry not found: $entry"
    return 127
  fi

  bash "$entry" "$@"
}
