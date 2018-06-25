#!/bin/bash
set -ueo pipefail
#set -x

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
SRC_DIR=$REPO_DIR/src

DEST_DIR=/usr/share/themes
THEME_NAME=Beaucoup
COLOR_VARIANTS=('' '-dark')
SIZE_VARIANTS=('')

GTK_VERSIONS=('3.18' '3.20' '3.22')
GS_VERSIONS=('3.18' '3.24' '3.26' '3.28')
LATEST_GS_VERSION=${GS_VERSIONS[-1]}

# Set a proper gnome-shell theme version
if [[ $(which gnome-shell 2> /dev/null) ]]; then
  CURRENT_GS_VERSION=$(gnome-shell --version | cut -d ' ' -f 3 | cut -d . -f -2)
  for version in "${GS_VERSIONS[@]}"; do
    if (( $(bc <<< "$CURRENT_GS_VERSION <= $version") )); then
      GS_VERSION=$version
      break
    elif (( $(bc <<< "$CURRENT_GS_VERSION > $LATEST_GS_VERSION") )); then
      GS_VERSION=$LATEST_GS_VERSION
      break
    fi
  done
else
  GS_VERSION=$LATEST_GS_VERSION
fi

usage() {
  printf "%s\\n" "Usage: $0 [OPTIONS...]"
  printf "\\n%s\\n" "OPTIONS:"
  printf "  %-25s%s\\n" "-d, --dest DIR" "Specify theme destination directory (Default: $DEST_DIR)"
  printf "  %-25s%s\\n" "-n, --name NAME" "Specify theme name (Default: $THEME_NAME)"
  printf "  %-25s%s\\n" "-c, --color VARIANTS..." "Specify theme color variant(s) [standard|dark|light] (Default: All variants)"
  printf "  %-25s%s\\n" "-s, --size VARIANT" "Specify theme size variant [standard|compact] (Default: All variants)"
  printf "  %-25s%s\\n" "-g, --gdm" "Install GDM theme"
  printf "  %-25s%s\\n" "-h, --help" "Show this help"
  printf "\\n%s\\n" "INSTALLATION EXAMPLES:"
  printf "%s\\n" "Install all theme variants into ~/.themes"
  printf "  %s\\n" "$0 --dest ~/.themes"
  printf "%s\\n" "Install all theme variants into ~/.themes including GDM theme"
  printf "  %s\\n" "$0 --dest ~/.themes --gdm"
  printf "%s\\n" "Install standard theme variant only"
  printf "  %s\\n" "$0 --color standard --size standard"
  printf "%s\\n" "Install specific theme variants with different name into ~/.themes"
  printf "  %s\\n" "$0 --dest ~/.themes --name MyTheme --color light dark --size compact"
}

install() {
  local dest=$1
  local name=$2
  local color=$3
  local size=$4

  [[ "$color" == '-dark' ]] && local ELSE_DARK=$color
  [[ "$color" == '-light' ]] && local ELSE_LIGHT=$color

  local THEME_DIR=$dest/$name$color$size

  # SC2115: Protect /.
  [[ -d "$THEME_DIR" ]] && rm -rf "${THEME_DIR:?}"

  echo "Installing '$THEME_DIR'..."

  mkdir -p                                                                      "$THEME_DIR"

  mkdir -p                                                                      "$THEME_DIR/gnome-shell"
  cp -r "$SRC_DIR/gnome-shell/assets"                            								"$THEME_DIR/gnome-shell/assets"
  cp -r "$SRC_DIR/gnome-shell/gnome-shell$size.css"           									"$THEME_DIR/gnome-shell/gnome-shell.css"
	cp -r "$SRC_DIR/gnome-shell/pad-osd.css"           														"$THEME_DIR/gnome-shell/pad-osd.css"

  mkdir -p                                                                      "$THEME_DIR/gtk-2.0"
  cp -r "$SRC_DIR/gtk-2.0/"{apps.rc,hacks.rc,main.rc}                           "$THEME_DIR/gtk-2.0"
  cp -r "$SRC_DIR/gtk-2.0/assets${ELSE_DARK:-}"                                 "$THEME_DIR/gtk-2.0/assets"
  cp -r "$SRC_DIR/gtk-2.0/gtkrc$color"                                          "$THEME_DIR/gtk-2.0/gtkrc"

  mkdir -p                                                                  		"$THEME_DIR/gtk-3.0"
  cp -r "$SRC_DIR/gtk-3.0/assets"                                   						"$THEME_DIR/gtk-3.0/assets"
  cp -r "$SRC_DIR/gtk-3.0/gtk-contained$color.css"                              "$THEME_DIR/gtk-3.0/gtk.css"
  [[ "$color" != '-dark' ]] && \
  cp -r "$SRC_DIR/gtk-3.0/gtk-contained-dark.css"                               "$THEME_DIR/gtk-3.0/gtk-dark.css"

	mkdir -p																																			"$THEME_DIR/xfwm4"
	cp -r "$SRC_DIR/xfwm4$color/"{themerc,*.png,*.xpm}														"$THEME_DIR/xfwm4"											
}

install_gdm() {
  local THEME_DIR=$1/$2$3$4
  # bakup and install files related to gdm theme
  if [[ ! -f /usr/share/gnome-shell/gnome-shell-theme.gresource.bak ]]; then
    cp -af /usr/share/gnome-shell/gnome-shell-theme.gresource{,.bak}
  fi
  if [[ -f /usr/share/gnome-shell/theme/ubuntu.css ]]; then
    if [[ ! -f /usr/share/gnome-shell/theme/ubuntu.css.bak ]]; then
      cp -af /usr/share/gnome-shell/theme/ubuntu.css{,.bak}
    fi
    cp -af "$THEME_DIR/gnome-shell/gnome-shell.css" /usr/share/gnome-shell/theme/ubuntu.css
  fi
  echo "Installing 'gnome-shell-theme.gresource'..."
  glib-compile-resources \
    --sourcedir="$THEME_DIR/gnome-shell" \
    --target=/usr/share/gnome-shell/gnome-shell-theme.gresource \
    "$THEME_DIR/gnome-shell/gnome-shell-theme.gresource.xml"
}

while [[ "$#" -gt 0 ]]; do
  case "${1:-}" in
    -d|--dest)
      dest="$2"
      if [[ ! -d "$dest" ]]; then
        echo "ERROR: Destination directory does not exist."
        exit 1
      fi
      shift 2
      ;;
    -n|--name)
      _name="$2"
      shift 2
      ;;
    -g|--gdm)
      gdm=true
      shift 1 
      ;;
    -c|--color)
      shift
      for variant in "$@"; do
        case "$variant" in
          standard)
            colors+=("${COLOR_VARIANTS[0]}")
            shift
            ;;
          dark)
            colors+=("${COLOR_VARIANTS[1]}")
            shift
            ;;
          light)
            colors+=("${COLOR_VARIANTS[2]}")
            shift
            ;;
          -*)
            break
            ;;
          *)
            echo "ERROR: Unrecognized color variant '$1'."
            echo "Try '$0 --help' for more information."
            exit 1
            ;;
        esac
      done
      ;;
    -s|--size)
      shift
      for variant in "$@"; do
        case "$variant" in
          standard)
            sizes+=("${SIZE_VARIANTS[0]}")
            shift
            ;;
          compact)
            sizes+=("${SIZE_VARIANTS[1]}")
            shift
            ;;
          -*)
            break
            ;;
          *)
            echo "ERROR: Unrecognized size variant '${1:-}'."
            echo "Try '$0 --help' for more information."
            exit 1
            ;;
        esac
      done
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unrecognized installation option '${1:-}'."
      echo "Try '$0 --help' for more information."
      exit 1
      ;;
  esac
done

if [[ ! -w "${dest:-$DEST_DIR}" ]]; then
  echo "Please run as root."
  exit 1
fi

for color in "${colors[@]:-${COLOR_VARIANTS[@]}}"; do
  for size in "${sizes[@]:-${SIZE_VARIANTS[@]}}"; do
    install "${dest:-$DEST_DIR}" "${_name:-$THEME_NAME}" "$color" "$size"
  done
done

if [[ "${gdm:-}" == true ]]; then
  install_gdm "${dest:-$DEST_DIR}" "${_name:-$THEME_NAME}" "$color" "$size"
fi

echo
echo "Done."