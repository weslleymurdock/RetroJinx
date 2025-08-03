#!/bin/bash
set -e

###################
#### VARIABLES ####
################### 

BASE_PATH=$(dirname "$(readlink -f "$0")")
RETROPIE_PATH="$BASE_PATH/submodules/RetroPie-Setup"
RYUJINX_PATH="$BASE_PATH/submodules/ryujinx"
RYUJINX_OUTPUT_PATH="/opt/retropie/emulators/ryujinx/"
RYUJINX_CSPROJ="$RYUJINX_PATH/src/Ryujinx/Ryujinx.csproj"
ES_CFG="/opt/retropie/configs/all/emulationstation/es_systems.cfg"
SYSTEM_XML=$(cat <<EOF
<system>
    <name>switch</name>
    <fullname>Nintendo Switch</fullname>
    <path>/home/${USER}/RetroPie/roms/switch</path>
    <extension>.nsp .xci</extension>
    <command>/opt/retropie/emulators/ryujinx/Ryujinx.sh %ROM%</command>
    <platform>switch</platform>
    <theme>switch</theme>
</system>
EOF
)

#####################
#### Functions ###### 
#####################
# 
#  Build RetroPie and Ryujinx
#  @param bool $ryujinx - Whether to build Ryujinx
#  @param bool $retropie - Whether to build RetroPie
#
function build($ryujinx = true, $retropie = true) 
{
  if [ "$retropie" = true ]; then
    echo "Building RetroPie..."
    cd "$RETROPIE_PATH"
    git pull origin main
    git checkout $(git describe --tags `git rev-list --tags --max-count=1`)
    git submodule update --init --recursive
    chmod +x retropie_setup.sh
    ./retropie_setup.sh --silent install
  fi
  if [ "$ryujinx" = true ]; then
    echo "Building Ryujinx..."
    cd "$RYUJINX_PATH"
    dotnet publish "$RYUJINX_CSPROJ" -c Release --build -o $RYUJINX_OUTPUT_PATH
    chmod +x /opt/retropie/emulators/ryujinx/Ryujinx.sh
  fi
}   

# 
# Install Ryujinx and configure EmulationStation
#
function install() 
{
  echo "Installing Ryujinx..."
  mkdir -p /opt/retropie/emulators/ryujinx/
  chmod +x /opt/retropie/emulators/ryujinx/Ryujinx.sh
  mkdir -p "$HOME/RetroPie/roms/switch"

  echo "Setting up EmulationStation..."
  mkdir -p "$(dirname "$ES_CFG")"

  if [ ! -f "$ES_CFG" ]; then
    echo "Making a new one es_systems.cfg file..."
    echo "<systemList>$SYSTEM_XML</systemList>" > "$ES_CFG"
  else
    echo "Verifying if the switch system have a configuration..."
    if ! xmlstarlet sel -t -m "/systemList/system/name" -v . -n "$ES_CFG" | grep -q "^switch$"; then
      echo "Adding the Switch system to es_systems.cfg..."
      xmlstarlet ed --inplace -s "/systemList" -t elem -n "systemTMP" -v "" \
        -s "/systemList/systemTMP" -t xml -n "." -v "$SYSTEM_XML" \
        -d "/systemList/systemTMP" "$ES_CFG"
    else
      echo "The Switch System is already present on the es_systems.cfg file."
    fi
  fi
  echo "Ryujinx installed successfully."
  echo "You can now run Ryujinx from EmulationStation or directly using the command: /opt/retropie/emulators/ryujinx/Ryujinx.sh"
}

# 
# Uninstall Ryujinx and remove it from EmulationStation configuration
#
function uninstall() 
{
  echo "Uninstalling Ryujinx..."
  rm -rf /opt/retropie/emulators/ryujinx/
  echo "Finished uninstalling Ryujinx."
  echo "Removing Ryujinx from EmulationStation configuration..."
  if [ -f "$ES_CFG" ]; then
    if xmlstarlet sel -t -m "/systemList/system/name" -v . -n "$ES_CFG" | grep -q "^switch$"; then
      xmlstarlet ed --inplace -d "/systemList/system[name='switch']" "$ES_CFG"
      echo "Ryujinx removed from EmulationStation configuration."
    else
      echo "Ryujinx was not found in EmulationStation configuration."
    fi
  else
    echo "EmulationStation configuration file not found."
  fi
}

#
# Update Ryujinx to the latest version
#
function update() 
{
  echo "Updating Ryujinx..."
  git -C "$RYUJINX_PATH" pull origin main
  git -C "$RYUJINX_PATH" checkout $(git -C "$RYUJINX_PATH" describe --tags `git -C "$RYUJINX_PATH" rev-list --tags --max-count=1`)
  git -C "$RYUJINX_PATH" submodule update --init --recursive
  echo "Ryujinx updated successfully."
}

###################
#### Root check ###
###################
if [ "$EUID" -ne 0 ]; then
  echo "Este script precisa ser executado como root (use sudo)."
  exit 1
fi

#####################
## Argument parser ##
#####################
for arg in "$@"; do
	case "$arg" in
		--build) 
      		update
      		build true true
		;;
    	--retropie-only)
			update
			build false true
		;;
		--ryujinx-only)
			update
			build true false
			install
		;;
		--uninstall) 
			uninstall
		;;
		*)
			echo "Performing update, build and install of Ryujinx and RetroPie."
			update
			build true true
			install
		;;
	esac
done
 
echo "Installation finished succesfully. Run 'emulationstation' to start."
