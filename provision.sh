#!/bin/bash

cd "`dirname \"$0\"`"
DIR="$(pwd)"

apt-get -y install vagrant

if ! which vagrant >/dev/null 2>&1 ; then
    echo "Vagrant must be installed."
    exit 1
fi

ROOT=$HOME/caas

mkdir -p $ROOT
cd $ROOT

git clone https://github.com/corajr/caas.git caas-git
git clone https://github.com/corajr/wp-zotero-sync caas-git


if ! which vv >/dev/null 2>&1 ; then
    (which brew >/dev/null 2>&1 && brew install bradp/vv/vv) || \ 
        (git clone https://github.com/bradp/vv && \
            cd vv && \
            echo export PATH=\"$(pwd):\$PATH\" >> ~/.bashrc)
fi

git clone git://github.com/Varying-Vagrant-Vagrants/VVV.git vvv
cd vvv

vagrant plugin install vagrant-hostsupdater
vagrant plugin install vagrant-triggers

cp "$DIR/vv-blueprints.json" $ROOT/vvv/vv-blueprints.json
vv create --domain plugin_trial.dev --name plugin_trial

rm -rf www/plugin_trial/htdocs/wp-content/themes/_s-master

cat <<EOF > Customfile

config.vm.synced_folder "$ROOT/caas-git", "/srv/www/plugin_trial/htdocs/wp-content/themes/_s-master"

config.vm.synced_folder "$ROOT/wp-zotero-sync", "/srv/www/plugin_trial/htdocs/wp-content/plugins/wp-zotero-sync"

EOF

vagrant up

rsync -rlve ssh --dry-run cjr@remeike.webfactional.com:/home/remeike/webapps/caas/wp-content/uploads/ $ROOT/vvv/www/plugin_trial/htdocs/wp-content/uploads/

(cd $ROOT/vvv; \
 ssh cjr@remeike.webfactional.com 'mysqldump --add-drop-table remeike_caas_wp | xz' | unxz > $ROOT/vvv/remeike_caas_wp.sql && \
	 vagrant ssh -c 'mysql -uroot -proot plugin_trial < /vagrant/remeike_caas_wp.sql')

