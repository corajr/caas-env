#!/bin/bash

set -e

cd "`dirname \"$0\"`"
DIR="$(pwd)"

if [ "$DIR" = "/" ]; then
    DIR=/vagrant
fi

which brew || ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

which vagrant || brew install Caskroom/cask/vagrant

which VBoxManage || brew install Caskroom/cask/virtualbox

if ! which vagrant >/dev/null 2>&1 ; then
    echo "Vagrant must be installed."
    exit 1
fi

mkdir -p ~/.ssh

if [ ! -f "$DIR/id_rsa" ]; then
    echo "Obtain the SSH key id_rsa first. Exiting"
    exit 1
fi

cp "$DIR/id_rsa" "$HOME/.ssh/caas_rsa"
cp "$DIR/id_rsa.pub" "$HOME/.ssh/caas_rsa.pub"

SSH_KEY="$HOME/.ssh/caas_rsa"

SSH="ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

export GIT_SSH_COMMAND=$SSH

ROOT=$(pwd)

pull_or_clone() {
	REPO_ADDR="$1"
	REPO_DIR="$2"
	if [ -d "$REPO_DIR" ]; then
		(cd "$REPO_DIR"; git pull)
	else
		git clone "$REPO_ADDR" "$REPO_DIR"
	fi
}

pull_or_clone git@github.com:corajr/caas.git caas-git
pull_or_clone git@github.com:corajr/wp-zotero-sync wp-zotero-sync

VV=$(which vv || true)

if [ -z "$VV" ]; then
	if which brew >/dev/null 2>&1; then
		brew install bradp/vv/vv
	else
        pull_or_clone git@github.com:bradp/vv.git vv
		VV=`pwd`/vv/vv
        (cd vv; echo export PATH=\"$(pwd):\$PATH\" >> ~/.bashrc)
	fi
fi

if [ ! -x "$VV" ]; then
	echo "vv is not executable; terminating."
	exit 1
fi

pull_or_clone git@github.com:Varying-Vagrant-Vagrants/VVV.git vvv
cd vvv

PLUGINS=`vagrant plugin list`

(echo $PLUGINS | grep vagrant-hostsupdater) || vagrant plugin install vagrant-hostsupdater
(echo $PLUGINS | grep vagrant-triggers) || vagrant plugin install vagrant-triggers

cp "$DIR/vv-blueprints.json" "$ROOT/vvv/vv-blueprints.json"

$SSH remeike@remeike.webfactional.com 'mysqldump --add-drop-table remeike_caas_wp | bzip2' | bzcat > "$ROOT/vvv/remeike_caas_wp.sql"

($VV list | grep plugin_trial) || \
    (yes | "$VV" create --blueprint plugin_trial \
       --domain plugin_trial.dev \
       --name plugin_trial \
       -db "$ROOT/vvv/remeike_caas_wp.sql" \
       --defaults)

rsync -rlv -e ssh remeike@remeike.webfactional.com:/home/remeike/webapps/caas/wp-content/uploads/ "$ROOT/vvv/www/plugin_trial/htdocs/wp-content/uploads/"

rm -rf www/plugin_trial/htdocs/wp-content/themes/_s-master

cat <<EOF > Customfile

config.vm.synced_folder "$ROOT/caas-git", "/srv/www/plugin_trial/htdocs/wp-content/themes/_s-master"

config.vm.synced_folder "$ROOT/wp-zotero-sync", "/srv/www/plugin_trial/htdocs/wp-content/plugins/wp-zotero-sync"

EOF


