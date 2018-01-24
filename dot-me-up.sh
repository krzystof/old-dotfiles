#!/usr/bin/env bash
set -e

DOTFILES=$(pwd)
release=`lsb_release -cs`

. ./prompt_utils.sh
. ./helpers.sh

function add_ppa() {
  ppa=$1
  if ! grep -q "^deb .*${ppa}" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
    sudo add-apt-repository -y ppa:${ppa}
    e_ok "${ppa} ppa added"
  fi
}

function apt_install() {
  pkg=$1
  if [ -v ${pkg} ]; then
    e_arrow "Installing ${pkg}"
    sudo apt-get install -y ${pkg}
    e_ok "${pkg} installed"
  fi
}

function symlink_dropbox() {
  dest=${HOME}/Dropbox/${1}
  link=${HOME}/$2

  if [ ! -L ${link} ] || [ `readlink ${link}` != $dest ]; then
    ln -s ${dest} ${link}
    e_ok "Symlink to Dropbox/${dest}"
  fi
}

function clone_github_repo() {
  cd ${DOTFILES}/repos
  repo=https://github.com/${1}.git
  if [ ! -d ${DOTFILES}/repos/${2} ]; then
    e_arrow "cloning from ${repo}"
    git clone --recursive ${repo} &> /dev/null
    e_ok "${1} cloned successfully"
  fi
}

function install_nerd_font() {
  font_dir=${HOME}/.local/share/fonts
  mkdir -p ${font_dir}
  if [ -d ${font_dir}/${1} ]; then
    ./nerd-fonts/install.sh $1
  fi
}

not_installed() {
  if type_exists $1 &> /dev/null; then
    return 0
  else
    return 1
  fi
}

e_header "Let's setup a new machine with Elementary OS, shall we"
echo
cd ${HOME}/Dotfiles

e_arrow "Updating the Dotfiles repo..."
git pull

add_ppa jonathonf/vim
add_ppa me-davidsansome/clementine
add_ppa mozillateam/firefox-next

sudo apt-get update &> /dev/null

apt_install vim
apt_install clementine
apt_install zsh
apt_install xcape
apt_install firefox

clone_github_repo ryanoasis/nerd-fonts nerd-fonts
clone_github_repo sorin-ionescu/prezto prezto

if [ ! -f ${DOTFILES}/repos/prezto/modules/prompt/functions/prompt_polly_setup ]; then
  ln -s ${DOTFILES}/files/prompt_polly_setup  ${DOTFILES}/repos/prezto/modules/prompt/functions/prompt_polly_setup
  e_arrow "Symlinked prezto prompt"
fi

install_nerd_font SauceCodePro
install_nerd_font Inconsolata

if ! type_exists dropbox; then
  e_arrow "installing dropbox"
  cd ${HOME}/Downloads
  wget https://www.dropbox.com/download?dl=packages/ubuntu/dropbox_2015.10.28_amd64.deb
  gdebi dropbox_2015.10.28_amd64.deb
  e_ok "dropbox installed, just login"
  seek_confirmation "is it synced yet?"
  if ! is_confirmed; then
    e_error "dropbox not synced yet! Please sign in and rerun this script after"
    exit 1
  fi
fi

if [ ! -d ${HOME}/Dropbox/Clementine ]; then
  e_error "dropbox not synced yet! Please sign in and rerun this script after"
  exit 1
fi

symlink_dropbox Clementine/albumcovers .config/Clementine/albumcovers
symlink_dropbox Clementine/Clementine.conf .config/Clementine/Clementine.conf
symlink_dropbox Clementine/clementine.db .config/Clementine/clementine.db

if [ ! -e ${HOME}/.vim ]; then
  ln -s ${HOME}/Dropbox/Vim ${HOME}/.vim
  e_ok "vim dir symlinked"
fi

symlinks=(zlogin zlogout zpreztorc zprofile zshenv zshrc tmux.conf gitconfig gitignore_global xprofile ctags vimrc)

for symlink in "${symlinks[@]}"; do
  if [ ! -L ${HOME}/.${symlink} ]; then
    ln -s ${DOTFILES}/files/${symlink} ${HOME}/.${symlink}
    e_ok "symlinked ${symlink}"
  fi
done

if [ ! -L "${HOME}/.zsh/completion" ]; then
  ln -s "${DOTFILES}/completion" "${HOME}/.zsh/completion"
fi

if [ `echo $SHELL` != /bin/zsh ]; then
  chsh -s /bin/zsh
  e_ok "changed default shell to zsh"
fi

if [ ! -d ${HOME}/.local/share/icons/bridge ]; then
  mkdir -p ${HOME}/.local/share/icons
  cp -R ${DOTFILES}/files/bridge ${HOME}/.local/share/icons/
fi

if ! type_exists tmux; then
  e_arrow "installing tmux 2.6"
  cd ${HOME}/Downloads
  wget https://github.com/tmux/tmux/releases/download/2.6/tmux-2.6.tar.gz
  tar -zcvf tmux-2.6.tar.gz
  ./configure && make
  sudo make install
  e_ok "tmux installed"
fi

if ! type_exists albert; then
  cd "${DOTFILES}"
  e_arrow "installing albert"
  wget -nv -O Release.key \
    https://build.opensuse.org/projects/home:manuelschneid3r/public_key
  sudo apt-key add - < Release.key
  rm -f Release.key
  sudo apt-get update
  sudo sh -c "echo 'deb http://download.opensuse.org/repositories/home:/manuelschneid3r/xUbuntu_16.04/ /' > /etc/apt/sources.list.d/albert.list"
  sudo apt-get install albert
  mkdir -p "${HOME}/.config/albert/org.albert.extension.kvstore"
  ln -s "${HOME}/Dropbox/AlbertKeyValues/kvstore.db" "${HOME}/.config/albert/org.albert.extension.kvstore/kvstoredb"
  e_ok "albert installed"
fi

if [ ! -d ${NVM_DIR} ]; then
  e_arrow "installing nvm"
  curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash
  sed '/$NVM_DIR/nvm.sh/d' "${HOME}/.zshrc"
  . "$NVM_DIR/nvm.sh"
  e_arrow "installing node"
  nvm install v8.1.3
  e_ok "nvm and node installed successfully"
fi

if [ ! -d "${HOME}/.config/yarn" ]; then
  e_arrow "installing yarn"
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
  sudo apt-get update && sudo apt-get install -y yarn
  e_ok "yarn installed successfully"
fi

if ! type_exists docker; then
  e_arrow "installing docker"
  sudo apt-get install \
      apt-transport-https \
      ca-certificates \
      curl \
      software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
  sudo apt-get update && sudo apt-get install -y docker-ce
  sudo groupadd docker
  sudo usermod -aG docker $USER
  sudo systemctl enable docker
  e_arrow "installing docker-compose"
  sudo curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  e_ok "docker installed successfully"
fi

if ! type_exists php; then
  e_arrow "installing php7.1"
  add_ppa ondrej/php
  sudo apt-get update && sudo apt-get install php7.1-cli php7.1-pdo php7.1-xml php7.1-curl php7.1-dom php7.1-gd php7.1-mbstring php7.1-zip
  e_ok "php7.1 installed"
fi

if ! type_exists composer; then
  e_arrow "installing composer"
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  php -r "if (hash_file('SHA384', 'composer-setup.php') === '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061') { echo 'Installer verified';  } else { echo 'Installer corrupt'; unlink('composer-setup.php');  } echo PHP_EOL;"
  php composer-setup.php
  php -r "unlink('composer-setup.php');"
  sudo mv composer.phar /usr/local/bin/composer
  e_ok "composer installed"
fi

if ! type_exists valet; then
  e_arrow "installing valet"
  composer global require cpriego/valet-linux
  valet install
  valet domain wip
  cd "${HOME}/Code"
  valet park
  e_ok "valet installed"
fi

# What needs to be done on a brand new system?
# - install elm
# - install elixir
# - move all helpers to helpers.sh

# symlinks:
# dconf
# terminator?
# elementary tweaks
# maybe sublime?
