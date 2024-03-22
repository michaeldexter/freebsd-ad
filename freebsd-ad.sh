#!/bin/sh

# Copyright 2021, 2024 Michael Dexter. All rights reserved
 
# v.1

pkg search samba

echo ; echo Enter a Samba version to install i.e. samba419
read samba_version

pkg install $samba_version
#samba419 and ldb22 are incompatible, but, supplanted by samba-ldbedit?
#which ldbedit || pkg install ldb22
#which nslookup || pkg install bind-tools

echo ; echo Killing samba smbd nmbd winbindd
#pkill samba smbd nmbd winbindd
service samba_server onestop

echo ; echo Renaming previous smb4.conf and krb5.conf if present
[ -f /usr/local/etc/smb4.conf ] && mv /usr/local/etc/smb4.conf /usr/local/etc/smb4.conf.previous
[ -f /usr/local/etc/krb5.conf ] && mv /usr/local/etc/krb5.conf /usr/local/etc/krb5.conf.previous

echo ; echo Deleting /var/db/samba4/*
rm -rf /var/db/samba4/*

echo ; echo Removing previous certificates
[ -f /var/db/samba4/private/tls/key.pem ] && \
	rm /var/db/samba4/private/tls/key.pem
[ -f /var/db/samba4/private/tls/cert.pem ] && \
	rm /var/db/samba4/private/tls/cert.pem

echo ; echo Enter a realm such as MYDOMAIN.MYCOMPANY.LOCAL:
read realm

echo ; echo Enter a domain such as MYDOMAIN:
read domain

echo ; echo Enter a strong administrator password \(will echo and be tested\)
read adminpass

echo ; echo Provisioning with samba-tool domain provision --use-rfc2307 \
	--realm=${domain}.$realm --domain=$domain \
	--server-role=dc --adminpass $adminpass \
	--option="ad dc functional level = 2016"
# --functional-level=2016

samba-tool domain provision --use-rfc2307 \
	--realm=${domain}.$realm --domain=$domain \
	--server-role=dc --adminpass $adminpass \
	--option="ad dc functional level = 2016"
# --functional-level=2016
#samba-tool domain provision: error: no such option: --functional-level

# Alternative flags to consider
# --dns-backend=BIND9_DLZ \
# --dnspass=INstall66 \
# --host-name=SAMBA-02.BROCKLEY-2016.HARTE-LYNE.CA \
# --host-ip=192.168.8.66 \
# --option="bind interfaces only=yes" \
# --option="interfaces=lo eth0" \
# --option="vfs objects"="freebsd" \

[ $? = 0 ] || \
	{ echo Provision failed according to the return value ; exit 1 ; }

[ -f /usr/local/etc/smb4.conf ] || \
	{ echo /usr/local/etc/smb4.conf failed to generate ; exit 1 ; }

echo ; echo The resulting /usr/local/etc/smb4.conf reads
cat /usr/local/etc/smb4.conf

echo ; echo Copying generated krb5.conf to /usr/local/etc/krb5.conf

cp /usr/local/share/samba*/setup/krb5.conf /usr/local/etc/krb5.conf

echo ; echo The resulting /usr/local/etc/krb5.conf reads
cat /usr/local/etc/krb5.conf

echo ; echo Creating /var/db/samba4/private/tls if missing
[ -d /var/db/samba4/private/tls ] || mkdir -p /var/db/samba4/private/tls

echo ; echo Generating TLS keys and certificates

# INTERACTIVE without -subj
openssl req -newkey rsa:2048 -keyout \
	/var/db/samba4/private/tls/key.pem \
	-nodes -x509 -days 365 -out \
	/var/db/samba4/private/tls/cert.pem -subj '/CN=localhost'

[ $? = 0 ] || \
	{ echo Key generation failed according to the return value ; exit 1 ; }

echo ; echo Running chmod 600 /var/db/samba4/private/tls/key.pem
chmod 600 /var/db/samba4/private/tls/key.pem

# Validation step... sample syntax
# https://support.acquia.com/hc/en-us/articles/360004119234-Verifying-the-validity-of-an-SSL-certificate

echo ; echo /var/db/samba4/private/tls/cert.pem signature is
openssl x509 -in cert.pem -noout -pubkey

echo ; echo /var/db/samba4/private/tls/key.pem signature is
openssl rsa -in key.pem -pubout

echo ; echo Adding keys to /usr/local/etc/smb4.conf

sed -i'' -e '/workgroup/a\
        tls enabled  = yes\
        tls keyfile  = /var/db/samba4/private/tls/key.pem\
        tls certfile = /var/db/samba4/private/tls/cert.pem\
        tls cafile   =\
' /usr/local/etc/smb4.conf

[ $? = 0 ] || \
	{ echo Key addition failed according to the return value ; exit 1 ; }

echo ; echo The resulting /usr/local/etc/smb4.conf reads
cat /usr/local/etc/smb4.conf

#echo Verifying that /var/db/samba4/bind-dns/named.conf was generated
#[ -f /var/db/samba4/bind-dns/named.conf ] || \
#	{ echo named.conf failed to generate ; exit 1 ; }

echo ; echo Generating a resolv.conf that points at 127.0.0.1 and 8.8.8.8

#echo search localdomain > /etc/resolv.conf
echo nameserver 127.0.0.1 > /etc/resolv.conf
echo nameserver 8.8.8.8 >> /etc/resolv.conf

echo ; echo /etc/resolv.conf reads
cat /etc/resolv.conf

echo
samba-tool domain level show

echo
echo From here temporarily enable samba_server with:
echo
echo service samba_server onestart
echo
echo Various test and configuration tools:
echo getaddrinfo MYDOMAIN.MYCOMPANY.LOCAL
echo samba-tool dns query localhost ${domain}.${realm} @ ALL -U administrator
echo samba-tool fsmo show
echo samba_dnsupdate --verbose --all-names
#echo nslookup ${domain}.${realm}
echo kinit administrator@${domain}.${realm}
#echo klist -v
echo smbclient -L //localhost -U administrator
echo samba-tool user create testuser
echo wbinfo -i testuser
echo wbinfo --name-to-sid testuser
echo smbclient -L //localhost -U testuser
echo net ads status -U testuser
echo wbinfo -t
echo samba-ldbedit...
echo samba-tool user list
echo samba-tool dbcheck
echo testparm -s
echo smbd -b
samba-tool drs showrepl
echo

exit 0
