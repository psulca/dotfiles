#!/bin/bash

#==============================================================================
# install.sh (v1)
#
# Un asistente de instalación interactivo y modular para WSL.
# - Pide datos de Git.
# - Permite elegir shells adicionales con un menú interactivo.
# - Permite elegir si instalar el prompt Starship.
# - Configura todo de forma inteligente según las elecciones del usuario.
#==============================================================================

set -e

# --- Funciones de Utilidad ---
info() {
  echo -e "\n\e[1;34mINFO:\e[0m $1"
}

success() {
  echo -e "\e[1;32m✅ $1\e[0m"
}

# ---
# FASE 1: ASISTENTE INTERACTIVO
# ---
echo "------------------------------------------------"
echo " Asistente de Configuración de Entorno WSL v4 "
echo "------------------------------------------------"

# 1.1: Pedir datos para Git
info "Primero, vamos a configurar Git."
read -p "Introduce tu nombre completo para Git: " git_name
read -p "Introduce tu email para Git: " git_email

# 1.2: Menú de selección de Shells
info "Bash se configurará por defecto como base."
info "Elige qué shells adicionales deseas instalar y configurar."

# --- Lógica del menú interactivo ---
# Opciones disponibles. Puedes añadir más aquí en el futuro (ej: "fish")
options=("zsh")
# Por defecto, zsh está pre-seleccionado
selected=(true)
cursor=0

# Función para dibujar el menú
draw_menu() {
  clear
  echo "Elige los shells a configurar (Usa ↑/↓, Espacio para marcar, Enter para confirmar):"
  for i in "${!options[@]}"; do
    if [ "$i" -eq "$cursor" ]; then
      echo -n "> "
    else
      echo -n "  "
    fi

    if [ "${selected[$i]}" = true ]; then
      echo -n "[x] "
    else
      echo -n "[ ] "
    fi
    
    echo "${options[$i]}"
  done
}

# Bucle principal del menú
while true; do
  draw_menu
  # Leer un solo caracter de la entrada
  read -rsn1 key
  case "$key" in
    "A") ((cursor > 0)) && ((cursor--));; # Flecha Arriba
    "B") ((cursor < ${#options[@]}-1)) && ((cursor++));; # Flecha Abajo
    " ") selected[$cursor]=$((!selected[$cursor]));; # Espacio
    "") break;; # Enter
  esac
done

# Guardar las shells elegidas en un array
CHOSEN_SHELLS=()
for i in "${!options[@]}"; do
  if [ "${selected[$i]}" = true ]; then
    CHOSEN_SHELLS+=("${options[$i]}")
  fi
done

# La primera shell elegida será la por defecto
DEFAULT_SHELL=${CHOSEN_SHELLS[0]}

# 1.3: Preguntar por Starship
info "Starship es un prompt rápido y multi-shell."
read -p "¿Deseas instalar y usar Starship en los shells configurados? (s/n): " setup_starship_choice
SETUP_STARSHIP=false
if [[ "$setup_starship_choice" == "s" || "$setup_starship_choice" == "S" ]]; then
  SETUP_STARSHIP=true
fi

# 1.4: Resumen de la configuración
clear
echo "------------------------------------------------"
echo " Configuración seleccionada:"
echo "------------------------------------------------"
echo "- Nombre Git: $git_name"
echo "- Email Git:  $git_email"
echo "- Shells a configurar: bash, ${CHOSEN_SHELLS[*]}"
[ -n "$DEFAULT_SHELL" ] && echo "- Shell por defecto: $DEFAULT_SHELL"
echo "- Instalar Starship: $SETUP_STARSHIP"
echo "------------------------------------------------"
read -p "Presiona Enter para comenzar la instalación..."

# ---
# FASE 2: EJECUCIÓN
# ---

# 2.1: Instalaciones Base
info "Actualizando sistema e instalando dependencias..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y build-essential curl file git unzip

info "Instalando Homebrew..."
if ! command -v brew &> /dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
else
  brew update
fi

# 2.2: Instalación de Herramientas
info "Instalando herramientas base con Homebrew..."
brew install git fnm
if [ "$SETUP_STARSHIP" = true ]; then
  info "Instalando Starship..."
  brew install starship
fi

# 2.3: Configuración de herramientas globales
info "Configurando Git..."
git config --global user.name "$git_name"
git config --global user.email "$git_email"
git config --global init.defaultBranch main

info "Instalando Node.js LTS con FNM..."
eval "$(fnm env)"
fnm install --lts
fnm default lts-latest

# ---
# FASE 3: CONFIGURACIÓN DE SHELLS
# ---

# 3.1: Configurar Bash (siempre)
info "Configurando .bashrc..."
bashrc_path=~/.bashrc
# Limpiar configuraciones previas de este script para evitar duplicados
sed -i '/# Dotfiles-Config-Start/,/# Dotfiles-Config-End/d' "$bashrc_path"
# Escribir el nuevo bloque de configuración
{
  echo '# Dotfiles-Config-Start'
  echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
  echo 'eval "$(fnm env --use-on-cd)"'
  if [ "$SETUP_STARSHIP" = true ]; then
    echo 'eval "$(starship init bash)"'
  fi
  echo '# Dotfiles-Config-End'
} >> "$bashrc_path"
success "Bash configurado."

# 3.2: Configurar shells adicionales elegidos
for shell in "${CHOSEN_SHELLS[@]}"; do
  if [[ "$shell" == "zsh" ]]; then
    info "Instalando y configurando zsh..."
    sudo apt-get install -y zsh
    if [ ! -d ~/.oh-my-zsh ]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    
    zshrc_path=~/.zshrc
    sed -i '/# Dotfiles-Config-Start/,/# Dotfiles-Config-End/d' "$zshrc_path"
    {
      echo '# Dotfiles-Config-Start'
      echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
      echo 'eval "$(fnm env --use-on-cd)"'
      if [ "$SETUP_STARSHIP" = true ]; then
        sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME=""/g' "$zshrc_path"
        echo 'eval "$(starship init zsh)"'
      fi
      echo '# Dotfiles-Config-End'
    } >> "$zshrc_path"
    success "zsh configurado."
  fi
  # Aquí podrías añadir 'elif [[ "$shell" == "fish" ]]; then ...' en el futuro
done

# 3.3: Establecer el shell por defecto
if [ -n "$DEFAULT_SHELL" ]; then
  info "Estableciendo $DEFAULT_SHELL como shell por defecto..."
  case "$DEFAULT_SHELL" in
    "zsh")
      chsh -s $(which zsh)
      success "Zsh es ahora el shell por defecto."
      ;;
  esac
fi

# --- Final ---
echo -e "\n------------------------------------------------"
success "¡Instalación completada según tus elecciones!"
info "Por favor, CIERRA Y VUELVE A ABRIR tu terminal para aplicar todos los cambios."
echo "------------------------------------------------"
