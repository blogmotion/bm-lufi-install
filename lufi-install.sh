#!/bin/bash
# lufi-install : installation de LUFI 
# Lufi : https://git.framasoft.org/luc/lufi de @framasky
#
# Author: Mr Xhark -> @xhark
# License : Creative Commons http://creativecommons.org/licenses/by-nd/4.0/deed.fr
# Website : http://blogmotion.fr 
#set -xe
VERSION="2016.06.23"

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
echo -e "#            Script d'installation de Lufi              #"
echo -e "#              Testé sur Debian 8.5 x64                 #"
echo -e "#                                                       #"
echo -e "#########################################################"
echo -e "$rescolor\n\n"

if [ "$UID" -ne "0" ]
then
	echo -e "\n${jaune}\tRun this script as root.$rescolor \n\n"
	exit 1
fi

echo -e "\n${jaune}Installation des dependances...${rescolor}"
apt-get install -y build-essential nginx git
cd $WWW

echo -e "\n${jaune}Git clone...${rescolor}" && sleep 1
git clone https://git.framasoft.org/luc/lufi.git

echo -e "\n${jaune}cpan Carton...${rescolor}" && sleep 1
echo "yes" | cpan Carton
cd lufi 

echo -e "\n${jaune}Carton install...${rescolor}" && sleep 1
carton install
cp lufi.conf.template lufi.conf

echo -e "${jaune}Configuration du vhost nginx...${rescolor}" && sleep 1
sed -i 's|var/www/lufi|var/www/html/lufi|' "$WWW/lufi/lufi.conf"
sed -i 's|#proxy|proxy|' "$WWW/lufi/lufi.conf"
sed -i 's|#contact|contact|' "$WWW/lufi/lufi.conf"


cat << EOF > /etc/nginx/sites-available/lufi
server {
    listen 80;

    # Adapt this to your domain!
    server_name _;

    access_log /var/log/nginx/lufi.success.log;
    error_log /var/log/nginx/lufi.error.log;

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
sed -i 's|var/www/lufi|var/www/html/lufi|' /etc/systemd/system/lufi.service
systemctl daemon-reload 
systemctl enable lufi.service
systemctl start lufi.service
systemctl restart nginx

echo -e "\n\n${magenta} --- FIN DU SCRIPT (v${VERSION})---\n${rescolor}"
exit 0