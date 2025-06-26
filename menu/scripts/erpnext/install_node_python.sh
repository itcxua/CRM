# === Обробка аргументів і читання YAML-конфігурації ===
CONFIG_FILE="config.yaml"

if ! command -v yq >/dev/null; then
  echo "🔧 Installing yq (YAML parser)..."
  sudo apt install -y yq
fi

for arg in "$@"
do
  case $arg in
    --branch=*)
      FRAPPE_BRANCH="${arg#*=}"
      shift
      ;;
  esac
done

if [ -z "$FRAPPE_BRANCH" ]; then
  if [ -f "$CONFIG_FILE" ]; then
    FRAPPE_BRANCH=$(yq '.frappe.branch' "$CONFIG_FILE")
  else
    echo "⚠️ config.yaml not found. Defaulting to version-14"
    FRAPPE_BRANCH="version-14"
  fi
fi

case "$FRAPPE_BRANCH" in
  version-14) REQUIRED_NODE="16"; REQUIRED_PYTHON="3.10" ;;
  version-15) REQUIRED_NODE="18"; REQUIRED_PYTHON="3.10" ;;
  develop)    REQUIRED_NODE="18"; REQUIRED_PYTHON="3.11" ;;
  *)          REQUIRED_NODE="16"; REQUIRED_PYTHON="3.10" ;;
esac

AutoInstall_node() {
  echo "🧰 Installing Node.js version $1 via NVM..."
  export NVM_DIR="$HOME/.nvm"
  if [ ! -d "$NVM_DIR" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
  else
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
  fi
  nvm install "$1"
  nvm use "$1"
  nvm alias default "$1"
}

AutoInstall_python() {
  echo "🐍 Installing Python version $1 via Pyenv..."
  if ! command -v pyenv >/dev/null; then
    curl https://pyenv.run | bash
    export PATH="$HOME/.pyenv/bin:$PATH"
    export PYENV_ROOT="$HOME/.pyenv"
    eval "$(pyenv init --path)"
    eval "$(pyenv virtualenv-init -)"
  else
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv virtualenv-init -)"
  fi
  pyenv install -s "$1"
  pyenv global "$1"
}

AutoInstall_node "$REQUIRED_NODE"
AutoInstall_python "$REQUIRED_PYTHON"

echo "✅ Selected Frappe branch: $FRAPPE_BRANCH"
echo "✅ Node.js: $REQUIRED_NODE | Python: $REQUIRED_PYTHON"