#!/bin/bash

set -e

# cd "`dirname \"$0\"`"
# DIR="$(pwd)"
DIR=/vagrant

add-apt-repository -y ppa:git-core/ppa
apt-get update
apt-get -y install vagrant
apt-get -y install git

if ! which vagrant >/dev/null 2>&1 ; then
    echo "Vagrant must be installed."
    exit 1
fi

if [ ! -f $DIR/config/id_rsa ]; then
	echo "Needs an SSH key in config/id_rsa"
	exit 1
fi

SSH_KEY=$DIR/config/id_rsa
SSH="ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

export GIT_SSH_COMMAND=$SSH

ROOT=$HOME/caas

mkdir -p $ROOT
cd $ROOT

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

VV=$(which vv)

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

vagrant plugin install vagrant-hostsupdater
vagrant plugin install vagrant-triggers

cp "$DIR/vv-blueprints.json" $ROOT/vvv/vv-blueprints.json

$SSH cjr@remeike.webfactional.com 'mysqldump --add-drop-table remeike_caas_wp | xz' | unxz > $ROOT/vvv/remeike_caas_wp.sql

$VV create --blueprint plugin_trial \
   --domain plugin_trial.dev \
   --name plugin_trial \
   -db $ROOT/vvv/remeike_caas_wp.sql \
   --defaults

rsync -rlv -e "$SSH" cjr@remeike.webfactional.com:/home/remeike/webapps/caas/wp-content/uploads/ $ROOT/vvv/www/plugin_trial/htdocs/wp-content/uploads/

rm -rf www/plugin_trial/htdocs/wp-content/themes/_s-master

cat <<EOF > Customfile

config.vm.synced_folder "$ROOT/caas-git", "/srv/www/plugin_trial/htdocs/wp-content/themes/_s-master"

config.vm.synced_folder "$ROOT/wp-zotero-sync", "/srv/www/plugin_trial/htdocs/wp-content/plugins/wp-zotero-sync"

EOF

vagrant up


