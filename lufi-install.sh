#!/bin/bash
# lufi-install : installation de LUFI en moteur SQLite
# License : Creative Commons http://creativecommons.org/licenses/by-nd/4.0/deed.fr
# Website : http://blogmotion.fr 
#
# LUFI : https://git.framasoft.org/fiat-tux/hat-softwares/lufi 
#        https://framapiaf.org/@framasky
#		 https://fiat-tux.fr/2018/10/30/lufi-0-03-est-sorti/
#
#set -xe
VERSION="2019.08.21"

# VARIABLES
WWW="/var/www/html"
blanc="\033[1;37m"
gris="\033[0;37m"
magenta="\033[0;35m"
rouge="\033[1;31m"
vert="\033[1;32m"
jaune="\033[1;33m"
bleu="\033[1;34m"
rescolor="\033[0m"

# DEBUT DU SCRIPT
echo -e "$vert"
echo -e "#########################################################"
echo -e "#                                                       #"
echo -e "#          Script d'installation de LUFI 0.04.2         #"
echo -e "#                avec le moteur SQLite                  #"
echo -e "#                                                       #"
echo -e "#              Testé sur Debian 9/10 (x64)              #"
echo -e "#                      by @xhark                        #"
echo -e "#                                                       #"
echo -e "#########################################################"
echo -e "                     $VERSION"
echo -e "$rescolor\n\n"
sleep 3

if [ "$UID" -ne "0" ]
then
	echo -e "\n${jaune}\tRun this script as root.$rescolor \n\n"
	exit 1
fi

echo -e "\n${jaune}Installation des dependances...${rescolor}"
apt-get install -y build-essential nginx git libssl-dev cpanminus
cd $WWW

echo -e "\n${jaune}Git clone...${rescolor}" && sleep 1
git clone https://framagit.org/fiat-tux/hat-softwares/lufi.git

echo -e "\n${jaune}cpan Carton...${rescolor}" && sleep 1
cpanm Carton
cd lufi 

echo -e "\n${jaune}Carton install...${rescolor}" && sleep 1
carton install --deployment --without=test --without=postgresql --without=mysql --without=ldap --without=htpasswd
cp lufi.conf.template lufi.conf

echo -e "\n${jaune}Configuration lufi.conf...${rescolor}" && sleep 1
sed -i 's|#proxy|proxy|' "$WWW/lufi/lufi.conf"
sed -i 's|#contact|contact|' "$WWW/lufi/lufi.conf"
sed -i 's|#report|report|' "$WWW/lufi/lufi.conf"
sed -i 's|#max_file_size|max_file_size|' "$WWW/lufi/lufi.conf"

echo -e "${jaune}Configuration du vhost nginx...${rescolor}" && sleep 1
cat << EOF > /etc/nginx/sites-available/lufi
server {
    listen 80;

    # Adapt this to your domain!
    server_name _;
	
    # nginx root
    root ${WWW}/lufi/;

    access_log /var/log/nginx/lufi.success.log;
    error_log /var/log/nginx/lufi.error.log;
	
    # taille maxiumum upload
    client_max_body_size 10G;

    location / {
        # Add cache for static files
        if (\$request_uri ~* ^/(img|css|font|js)/) {
            add_header Expires "Thu, 31 Dec 2037 23:55:55 GMT";
            add_header Cache-Control "public, max-age=315360000";
        }
        # HTTPS only header, improves security
        #add_header Strict-Transport-Security "max-age=15768000";

        # Adapt this to your configuration (port, subdirectory (see below))
        proxy_pass  http://127.0.0.1:8081;

        # Really important! Lufi uses WebSocket, it won't work without this
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

        # If you want to log the remote port of the file senders, you'll need that
        proxy_set_header X-Remote-Port \$remote_port;

        proxy_set_header X-Forwarded-Proto \$scheme;

        # We expect the downstream servers to redirect to the right hostname, so don't do any rewrites here.
        proxy_redirect     off;
    }
}
EOF

ln -s /etc/nginx/sites-available/lufi /etc/nginx/sites-enabled/lufi
unlink /etc/nginx/sites-enabled/default

echo -e "\n${jaune}Permissions www-data...${rescolor}" && sleep 1
chown -R www-data:www-data $WWW/lufi

echo -e "\n${jaune}Config et restart des services...${rescolor}" && sleep 1
cp utilities/lufi.service /etc/systemd/system
sed -i "s|/var/www/lufi|${WWW}/lufi|" /etc/systemd/system/lufi.service
systemctl daemon-reload 
systemctl enable lufi.service
systemctl start lufi.service
systemctl restart nginx

echo -e "\n\n${magenta} --- FIN DU SCRIPT (v${VERSION})---\n${rescolor}"
echo -e "\n${rouge}Merci de modifier les variables  par défaut 'contact', 'report' et 'secrets' dans \n $WWW/lufi/lufi.conf ${rescolor}\n"
exit 0
