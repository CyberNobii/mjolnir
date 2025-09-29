#!/usr/bin/env bash
set -euo pipefail
# set -u was in original; using -euo pipefail for safer execution

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

info() { printf "${BLUE}[ℹ] %s${RESET}\n" "$*"; }
ok()   { printf "${BLUE}[✓] %s${RESET}\n" "$*"; }
warn() { printf "${RED}[⚠] %s${RESET}\n" "$*"; }
err()  { printf "${RED}[🚨] %s${RESET}\n" "$*"; }

detect_os() {
  if [ -n "${PREFIX-}" ] && command -v pkg >/dev/null 2>&1; then
    echo "Termux"
  elif [[ "${OSTYPE:-}" == "linux-gnu"* ]]; then
    echo "Linux"
  elif [[ "${OSTYPE:-}" == "darwin"* ]]; then
    echo "macOS"
  else
    echo "Unknown"
  fi
}

show_os_details() {
  printf "${BLUE}========= DEVICE INFORMATION =========${RESET}\n"
  printf "${BLUE}Platform   : %s${RESET}\n" "$os"
  printf "${BLUE}Kernel     : %s${RESET}\n" "$(uname -r)"
  printf "${BLUE}Arch       : %s${RESET}\n" "$(uname -m)"
  printf "${BLUE}Hostname   : %s${RESET}\n" "$(hostname)"
  printf "${BLUE}Uptime     : %s${RESET}\n" "$(uptime -p 2>/dev/null || echo 'N/A')"
  printf "${BLUE}User       : %s${RESET}\n" "$(whoami)"

  local_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")"
  public_ip="$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || echo "N/A")"
  printf "${BLUE}Local IP   : %s${RESET}\n" "${local_ip:-N/A}"
  printf "${BLUE}Public IP  : %s${RESET}\n" "${public_ip}"
}

check_internet() {
  info "Checking internet connection..."
  # make a simple HTTP HEAD with timeout; silence output; return non-zero on fail
  if curl -s --head --max-time 5 https://www.google.com >/dev/null 2>&1; then
    ok "Internet connection is active."
  else
    err "No internet connection. Please check your network and try again."
    exit 1
  fi
}

loading_bar() {
  info "Preparing installation..."
  bar="####################"
  for i in $(seq 1 20); do
    printf "\r${BLUE}Loading: [%-20s] %d%%%s" "${bar:0:$i}" $((i*5)) "${RESET}"
    sleep 0.03
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
  # prefer python3 binary
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD=python3
    PIP_CMD=pip3
  elif command -v python >/dev/null 2>&1; then
    # ensure python is v3
    pyver=$(( $(python -c 'import sys; print(sys.version_info[0])' 2>/dev/null || echo 0) ))
    if [ "$pyver" -ge 3 ]; then
      PYTHON_CMD=python
      PIP_CMD=pip
    fi
  fi

  if [ -z "${PYTHON_CMD:-}" ]; then
    return 1
  fi

  ok "Using Python: $($PYTHON_CMD --version 2>&1 | tr -d '\n')"
  return 0
}

install_python_if_missing() {
  detect_python && return 0
  pm=$(detect_pkg_manager)
  [ -z "$pm" ] && err "No package manager found. Install Python manually." && return 1
  info "Installing Python 3 with $pm"
  case "$pm" in
    pkg) pkg update -y >/dev/null 2>&1 && pkg install -y python clang >/dev/null 2>&1 ;;
    apt) sudo apt-get update -y >/dev/null 2>&1 && sudo apt-get install -y python3 python3-pip python3-venv build-essential >/dev/null 2>&1 ;;
    dnf) sudo dnf install -y python3 python3-pip python3-venv gcc >/dev/null 2>&1 ;;
    yum) sudo yum install -y python3 python3-pip python3-venv gcc >/dev/null 2>&1 ;;
    pacman) sudo pacman -Syu --noconfirm python python-pip python-virtualenv >/dev/null 2>&1 ;;
    apk) sudo apk add --no-cache python3 py3-pip py3-virtualenv build-base >/dev/null 2>&1 ;;
    brew) brew update >/dev/null 2>&1 && brew install python >/dev/null 2>&1 ;;
    *) err "Unable to install python automatically on this platform." && return 1 ;;
  esac

  detect_python || return 1
}

setup_python_env() {
  if [ "$os" = "Termux" ]; then
    # Termux: use global pip (venv often doesn't work there)
    if command -v pip >/dev/null 2>&1; then
      PIP_CMD=pip
    elif command -v pip3 >/dev/null 2>&1; then
      PIP_CMD=pip3
    else
      err "pip/pip3 not found in Termux. Try: pkg install python python-pip"
      exit 1
    fi
    ok "Detected Termux → installing Python modules globally using $PIP_CMD"
  else
    # Non-Termux: try to create & activate venv
    if [ ! -d "$VENV_DIR" ]; then
      info "Creating virtual environment at $VENV_DIR..."
      if ! $PYTHON_CMD -m venv "$VENV_DIR" >/dev/null 2>&1; then
        warn "Failed to create venv. Will attempt to install python3-venv (if available) and retry."
        pm=$(detect_pkg_manager)
        case "$pm" in
          apt) sudo apt-get install -y python3-venv >/dev/null 2>&1 || true ;;
          dnf) sudo dnf install -y python3-venv >/dev/null 2>&1 || true ;;
          yum) sudo yum install -y python3-venv >/dev/null 2>&1 || true ;;
          pacman) sudo pacman -S --noconfirm python-virtualenv >/dev/null 2>&1 || true ;;
          apk) sudo apk add py3-virtualenv >/dev/null 2>&1 || true ;;
          brew) brew install python >/dev/null 2>&1 || true ;;
        esac
        # try again
        if ! $PYTHON_CMD -m venv "$VENV_DIR" >/dev/null 2>&1; then
          warn "Could not create venv after retrying. Falling back to global pip3."
          if command -v pip3 >/dev/null 2>&1; then
            PIP_CMD=pip3
            ok "Using global pip3: $PIP_CMD"
            return 0
          else
            err "pip3 not found. Please install pip or fix venv support."
            exit 1
          fi
        fi
      fi
    fi

    # Activate venv
    if [ -f "$VENV_DIR/bin/activate" ]; then
      # shellcheck disable=SC1091
      source "$VENV_DIR/bin/activate"
      PIP_CMD="pip"
      ok "Activated virtual environment: $VENV_DIR (pip -> $PIP_CMD)"
    else
      err "Virtualenv activation script not found in $VENV_DIR/bin/activate"
      err "Try to create manually & Try again"
      exit 1
    fi
  fi
}

install_pip_packages() {
  info "Installing Python modules..."
  # ensure pip variable is set
  if [ -z "${PIP_CMD:-}" ]; then
    if command -v pip3 >/dev/null 2>&1; then
      PIP_CMD=pip3
    elif command -v pip >/dev/null 2>&1; then
      PIP_CMD=pip
    else
      err "pip not found. Aborting package installation."
      return 1
    fi
  fi

  "$PIP_CMD" install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
  for pkg in "${PIP_PACKAGES[@]}"; do
    info "Installing $pkg..."
    if "$PIP_CMD" install --no-cache-dir "$pkg" >/dev/null 2>&1; then
      ok "$pkg installed"
    else
      warn "Failed to install $pkg with $PIP_CMD. Trying verbose install for details..."
      if ! "$PIP_CMD" install --no-cache-dir "$pkg"; then
        err "Failed to install $pkg (verbose). Continue? (y/n)"
        read -r answer
        if [ "$answer" != "y" ]; then
          return 1
        fi
      fi
    fi
  done
}

run_tool() {
  clear
  if [ -f "$SCRIPT" ]; then
    ok "Running $SCRIPT..."
    # Use Python from venv if activated, else fallback to $PYTHON_CMD
    if command -v python >/dev/null 2>&1 && [ -n "${VIRTUAL_ENV:-}" ]; then
      python "$SCRIPT"
    else
      "$PYTHON_CMD" "$SCRIPT"
    fi
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
