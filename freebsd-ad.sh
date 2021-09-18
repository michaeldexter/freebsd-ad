#!/bin/sh
 
which samba || \
{ echo Samba missing - pkg install samba413 ldb22 bind-tools ; exit 1 ; }

echo Killing samba smbd nmbd winbindd
#pkill samba smbd nmbd winbindd
service samba_server onestop

echo Removing previous configuration
rm -rf /usr/local/etc/smb4.conf /var/db/samba4/*

echo Removing previous certificates
[ -f /var/db/samba4/private/tls/key.pem ] && \
	rm /var/db/samba4/private/tls/key.pem
[ -f /var/db/samba4/private/tls/cert.pem ] && \
	rm /var/db/samba4/private/tls/cert.pem

echo Enter a domain such as AD
read domain

echo Enter a realm such as TESTDOMAIN.COM
read realm

echo Enter an administraor password \(will echo\)
read adminpass

echo Provisioning with samba-tool domain provision --use-rfc2307 \
	 --realm=${domain}.$realm --domain=$domain \
	 --server-role=dc --adminpass $adminpass

samba-tool domain provision --use-rfc2307 \
         --realm=${domain}.$realm --domain=$domain \
         --server-role=dc --adminpass $adminpass

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

echo The resulting /usr/local/etc/smb4.conf reads
cat /usr/local/etc/smb4.conf

echo Copying generated krb5.conf to /usr/local/etc/krb5.conf

cp /usr/local/share/samba*/setup/krb5.conf /usr/local/etc/krb5.conf

echo The resulting /usr/local/etc/krb5.conf reads
cat /usr/local/etc/krb5.conf

echo Creating /var/db/samba4/private/tls if missing
[ -d /var/db/samba4/private/tls ] || mkdir -p /var/db/samba4/private/tls

echo Generating TLS keys and certificates

# INTERACTIVE without -subj
openssl req -newkey rsa:2048 -keyout \
	/var/db/samba4/private/tls/key.pem \
	-nodes -x509 -days 365 -out \
	/var/db/samba4/private/tls/cert.pem -subj '/CN=localhost'

[ $? = 0 ] || \
	{ echo Key generation failed according to the return value ; exit 1 ; }

echo Running chmod 600 /var/db/samba4/private/tls/key.pem
chmod 600 /var/db/samba4/private/tls/key.pem

# Validation step... sample syntax
# https://support.acquia.com/hc/en-us/articles/360004119234-Verifying-the-validity-of-an-SSL-certificate

echo /var/db/samba4/private/tls/cert.pem signature is
openssl x509 -in cert.pem -noout -pubkey

echo /var/db/samba4/private/tls/key.pem signature is
openssl rsa -in key.pem -pubout

echo Adding keys to /usr/local/etc/smb4.conf

sed -i'' -e '/workgroup/a\
        tls enabled  = yes\
        tls keyfile  = /var/db/samba4/private/tls/key.pem\
        tls certfile = /var/db/samba4/private/tls/cert.pem\
        tls cafile   =\
' /usr/local/etc/smb4.conf

[ $? = 0 ] || \
	{ echo Key addition failed according to the return value ; exit 1 ; }

echo The resulting /usr/local/etc/smb4.conf reads
cat /usr/local/etc/smb4.conf

#echo Verifying that /var/db/samba4/bind-dns/named.conf was generated
#[ -f /var/db/samba4/bind-dns/named.conf ] || \
#	{ echo named.conf failed to generate ; exit 1 ; }

echo Generating a resolv.conf that points at 127.0.0.1 and 8.8.8.8

#echo search localdomain > /etc/resolv.conf
echo nameserver 127.0.0.1 > /etc/resolv.conf
echo nameserver 8.8.8.8 >> /etc/resolv.conf

echo /etc/resolv.conf reads
cat /etc/resolv.conf

echo
echo From here enable samba_server with:
echo
echo service onestart samba_server
echo
echo Various test and configuration tools:
echo samba-tool dns query localhost ${domain}.${realm} @ ALL -U administrator
echo samba-tool fsmo show
echo samba_dnsupdate --verbose --all-names
echo nslookup ${domain}.${realm}
echo kinit administrator@${domain}.${realm}
echo klist -v
echo smbclient -L //localhost -U administrator
echo samba-tool user create testuser
echo wbinfo -i testuser
echo wbinfo --name-to-sid testuser
echo ldbedit...
echo samba-tool user list
echo samba-tool dbcheck
echo testparm -s
echo

exit 0

