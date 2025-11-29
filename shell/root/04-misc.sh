function clipf {
    xclip -sel clip < $1
}

function rainbowfastfetch {
    hyfetch -p rainbow -b fastfetch --args="--localip-show-ipv4 false"
}

function gaymenfastfetch {
    hyfetch -p gay-men -b fastfetch --args="--localip-show-ipv4 false"
}

function rffetch {
    cd ~/
    rainbowfastfetch
}

function gmffetch {
    cd ~/
    gaymenfastfetch
}

function szsh {
    source $HOME/.zshrc
}