
set -u

RED="\033[1;31m"
BLUE="\033[1;34m"
RESET="\033[0m"

PIP_PACKAGES=(instaloader requests beautifulsoup4 colorama)
VENV_DIR=".venv"
PYTHON_CMD=""
PIP_CMD=""
SCRIPT="mjolnir.py"

banner() {
  clear
  printf "${RED}
███▄ ▄███▓▄▄▄██▀▀▀██▓     ███▄    █  ██▓ ██▀███  
▓██▒▀█▀ ██▒  ▒██  ▓██▒     ██ ▀█   █ ▓██▒▓██ ▒ ██▒
▓██    ▓██░  ░██  ▒██░    ▓██  ▀█ ██▒▒██▒▓██ ░▄█ ▒
▒██    ▒██▓██▄██▓ ▒██░    ▓██▒  ▐▌██▒░██░▒██▀▀█▄  
▒██▒   ░██▒▓███▒  ░██████▒▒██░   ▓██░░██░░██▓ ▒██▒
░ ▒░   ░  ░▒▓▒▒░  ░ ▒░▓  ░░ ▒░   ▒ ▒ ░▓  ░ ▒▓ ░▒▓░
░  ░      ░▒ ░▒░  ░ ░ ▒  ░░ ░░   ░ ▒░ ▒ ░  ░▒ ░ ▒░
░      ░   ░ ░ ░    ░ ░      ░   ░ ░  ▒ ░  ░░   ░ 
       ░   ░   ░      ░  ░         ░  ░     ░     

${RESET}"
  printf "${RED}[INFO] Setup Script Starting...${RESET}\n"
}

info() { printf "${RED}{ℹ] %s${RESET}\n" "$*"; }
ok()   { printf "${RED}[✓]   %s${RESET}\n" "$*"; }
warn() { printf "${RED}[⚠] %s${RESET}\n" "$*"; }
err()  { printf "${RED}[🚨]  %s${RESET}\n" "$*"; }

detect_os() {
  if [ -n "${PREFIX-}" ] && command -v pkg >/dev/null 2>&1; then
    echo "Termux"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Linux"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS"
  else
    echo "Unknown"
  fi
}

show_os_details() {
  printf "${BLUE}========= DEVICE INFORMATION =========${RESET}\n"
  printf "${BLUE}Platform   : $os${RESET}\n"
  printf "${BLUE}Kernel     : $(uname -r)${RESET}\n"
  printf "${BLUE}Arch       : $(uname -m)${RESET}\n"
  printf "${BLUE}Hostname   : $(hostname)${RESET}\n"
  printf "${BLUE}Uptime     : $(uptime -p 2>/dev/null || echo 'N/A')${RESET}\n"
  printf "${BLUE}User       : $(whoami)${RESET}\n"

  local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  public_ip=$(curl -s --max-time 3 https://api.ipify.org || echo "N/A")
  printf "${BLUE}Local IP   : ${local_ip:-N/A}${RESET}\n"
  printf "${BLUE}Public IP  : ${public_ip}${RESET}\n"

  if [ "$os" = "Termux" ]; then
    printf "${BLUE}PackageMgr : pkg${RESET}\n"
    if command -v getprop >/dev/null 2>&1; then
      printf "${BLUE}Manufacturer: $(getprop ro.product.manufacturer)${RESET}\n"
      printf "${BLUE}Model       : $(getprop ro.product.model)${RESET}\n"
      printf "${BLUE}Android Ver : $(getprop ro.build.version.release)${RESET}\n"
    fi
    printf "${BLUE}Storage    : $(df -h /data | awk 'NR==2 {print $4 " free of " $2}')${RESET}\n"
  elif [ "$os" = "Linux" ]; then
    [ -f /etc/os-release ] && . /etc/os-release && printf "${BLUE}Distro     : $NAME $VERSION${RESET}\n"
    cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
    cores=$(grep -c ^processor /proc/cpuinfo)
    printf "${BLUE}CPU        : $cpu ($cores cores)${RESET}\n"
    printf "${BLUE}RAM        : $(free -h | awk '/Mem:/ {print $2 " total, " $3 " used"}')${RESET}\n"
    printf "${BLUE}Storage    : $(df -h / | awk 'NR==2 {print $4 " free of " $2}')${RESET}\n"
  elif [ "$os" = "macOS" ]; then
    printf "${BLUE}macOS Ver  : $(sw_vers -productVersion)${RESET}\n"
    printf "${BLUE}CPU        : $(sysctl -n machdep.cpu.brand_string)${RESET}\n"
    printf "${BLUE}Cores      : $(sysctl -n hw.ncpu)${RESET}\n"
    printf "${BLUE}RAM        : $(($(sysctl -n hw.memsize)/1024/1024/1024)) GB${RESET}\n"
    printf "${BLUE}Storage    : $(df -h / | awk 'NR==2 {print $4 " free of " $2}')${RESET}\n"
  fi
}

check_internet() {
  info "Checking internet connection..."
  if curl -s --head --request GET https://www.google.com 5 >/dev/null; then
    ok "Internet connection is active."
  else
    err "No internet connection. Please check your network and try again."
    exit 1
  fi
}

loading_bar() {
  info "Preparing installation..."
  bar="####################"
  for i in {1..20}; do
    printf "\r${RED}Loading: [%-20s] %d%%${RESET}" "${bar:0:$i}" $((i*5))
    sleep 0.05
  done
  echo ""
}

detect_pkg_manager() {
  if [ -n "${PREFIX-}" ] && command -v pkg >/dev/null 2>&1; then
    echo "pkg"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v apk >/dev/null 2>&1; then
    echo "apk"
  elif command -v brew >/dev/null 2>&1; then
    echo "brew"
  else
    echo ""
  fi
}

detect_python() {
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD=python3
  elif command -v python >/dev/null 2>&1; then
    ver=$(( $(python -c 'import sys; print(sys.version_info[0])') 2>/dev/null || echo 0 ))
    [ "$ver" -ge 3 ] && PYTHON_CMD=python
  fi
  [ -z "$PYTHON_CMD" ] && return 1
  ok "Using Python: $($PYTHON_CMD --version 2>&1 | tr -d '\n')"
}

install_python_if_missing() {
  detect_python && return 0
  pm=$(detect_pkg_manager)
  [ -z "$pm" ] && err "No package manager found. Install Python manually." && return 1
  info "Installing Python 3 with $pm"
  case "$pm" in
    pkg) pkg update -y >/dev/null 2>&1 && pkg install -y python clang >/dev/null 2>&1 ;;
    apt) sudo apt-get update -y >/dev/null 2>&1 && sudo apt-get install -y python3 python3-pip build-essential >/dev/null 2>&1 ;;
    dnf) sudo dnf install -y python3 python3-pip gcc >/dev/null 2>&1 ;;
    yum) sudo yum install -y python3 python3-pip gcc >/dev/null 2>&1 ;;
    pacman) sudo pacman -Syu --noconfirm python base-devel >/dev/null 2>&1 ;;
    apk) sudo apk add --no-cache python3 py3-pip build-base >/dev/null 2>&1 ;;
    brew) brew update >/dev/null 2>&1 && brew install python >/dev/null 2>&1 ;;
  esac
  detect_python || return 1
}

setup_python_env() {
  if [ "$os" = "Termux" ]; then
    PIP_CMD="pip"
    ok "Installing Python modules globally (Termux)"
  else
    [ -d "$VENV_DIR" ] || $PYTHON_CMD -m venv "$VENV_DIR" >/dev/null 2>&1
    source "$VENV_DIR/bin/activate"
    PIP_CMD="pip"
    ok "Using virtual environment: $VENV_DIR"
  fi
}

install_pip_packages() {
  info "Installing Python modules..."
  $PIP_CMD install --upgrade pip setuptools wheel >/dev/null 2>&1
  for pkg in "${PIP_PACKAGES[@]}"; do
    info "Installing $pkg..."
    if $PIP_CMD install --no-cache-dir "$pkg" >/dev/null 2>&1; then
      ok "$pkg installed"
    else
      err "Failed to install $pkg"
      return 1
    fi
  done
}

run_tool() {
  clear
  if [ -f "$SCRIPT" ]; then
    ok "Running $SCRIPT..."
    $PYTHON_CMD "$SCRIPT"
  else
    warn "No $SCRIPT found in this directory."
  fi
}

main() {
  banner
  os=$(detect_os)
  info "Detected environment: $os"
  show_os_details
  check_internet
  loading_bar
  install_python_if_missing || exit 1
  setup_python_env
  install_pip_packages || exit 1
  ok "Setup completed successfully!"
  sleep 1
  run_tool
}

main
