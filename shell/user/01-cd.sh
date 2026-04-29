function cdap {
  cd $HOME/.local/share/applications/$1
}

function cdc {
  cd $HOME/Chem/$1
}

function cdwindc {
  mount_wind
  cd /wind/Pictures/Chem/$1
}

function cddc {
  cd $HOME/Documents/$1
}

function cddo {
  cd $HOME/Downloads/$1
}

function cddf {
  DATE=$(date +"%Y-%m-%d")
  if ! [[ -d "/arch$HOME/.files/$DATE" ]]; then
    mkdir -p /arch$HOME/.files/$DATE
  fi
  cd /arch$HOME/.files/$DATE
}
function cdg {
  cd $HOME/GitHub/$1
}

function cdgm {
  cdg mine/$1
}

function cdcf {
  cdgm config/$1
}

function cdfgi {
  cd $ARCHFGI/$1
}

function cdhc {
  cdcf hyprland-configs/$1
}

function cdim {
  cd $ARCHIM/$1
}

function cdnc {
  cd $NIXCFG/$1
}

function cdgo {
  cdg others/$1
}

function cdm {
  cd $HOME/Music/$1
}

function cdp {
  cd $HOME/Pictures/$1
}

function cdps {
  cdp "Screenshots/$1"
}

function cdphd {
  cd /arch$HOME/PhD/$1
}

function cdrec {
  cd $ARCHGBM/recipes/$1
}

function cdv {
  cd $HOME/Videos/$1
}

function cdvb {
  cd $VBM/$1
}

function cdvi {
  cd $ISO/$1
}

function cdvm {
  cd $HOME/VirtMachines/$1
}