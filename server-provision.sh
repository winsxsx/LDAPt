#!/bin/bash

PASSWORD="seCrEtP@ssw0r"

sudo yum install -y openldap openldap-servers openldap-clients
sudo amazon-linux-extras install epel -y
sudo systemctl enable --now slapd

sudo slappasswd -s ${PASSWORD} > hash
sudo sed -i "s%PASSWORD%$(cat hash)%" /tmp/ldif/ldaprootpasswd.ldif /tmp/ldif/ldapdomain.ldif /tmp/ldif/ldapuser.ldif
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /tmp/ldif/ldaprootpasswd.ldif
sudo cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
sudo chown -R ldap:ldap /var/lib/ldap/
sudo systemctl restart slapd

sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif 
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/ldif/ldapdomain.ldif

sudo ldapadd -w ${PASSWORD} -x -D cn=Manager,dc=devopslab,dc=com -f /tmp/ldif/baseldapdomain.ldif
sudo ldapadd -w ${PASSWORD} -x -D "cn=Manager,dc=devopslab,dc=com" -f /tmp/ldif/ldapgroup.ldif
sudo ldapadd -w ${PASSWORD} -x -D cn=Manager,dc=devopslab,dc=com -f /tmp/ldif/ldapuser.ldif

sudo yum install -y epel-release
sudo yum install -y phpldapadmin

sudo sed -i "397s%// %%" /etc/phpldapadmin/config.php
sudo sed -i "398s%^%// %" /etc/phpldapadmin/config.php
sudo systemctl enable httpd
sudo systemctl restart httpd
