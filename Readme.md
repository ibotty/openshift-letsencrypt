# Automatic Certificates for Openshift Routes

It will manage all `route`s with (by default) `butter.sh/letsencrypt-managed=yes` labels in the project/namespace, it's deployed in.
Certificates will be stored in secrets starting with `letsencrypt-`.


## Limitations
For now, there are the following limitations.

 * It only implements `http-01`-type verification, better known as "Well-Known".
 * Multiple domains per certificate are not supported. See issue #1.
 * It will not create the letsencrypt account.
   It needs to be created before deploying.
   See Section **Installation** below.
 * It doesn't work cross-namespace. See issue #4.


## Customizing

The following env variables can be used.

 * `LETSENCRYPT_ROUTE_SELECTOR` (*optional*, defaults to `butter.sh/letsencrypt-managed=yes`), to filter the routes to use;
 * `LETSENCRYPT_RENEW_BEFORE_DAYS` (*optional*, defaults to `30`), renew this number of days before the certificate is about to expire;
 * `LETSENCRYPT_CONTACT_EMAIL` (*required for account generation*), the email that will be used by the ACME CA;
 * `LETSENCRYPT_CA` (*optional*, defaults to `https://acme-v01.api.letsencrypt.org/directory`);
 * `LETSENCRYPT_KEYTYPE` (*optional*, defaults to `rsa`), the key algorithm to use;
 * `LETSENCRYPT_KEYSIZE` (*optional*, defaults to `4096`), the size in bit for the private keys (if applicable);



## Implementation Details

### Secrets

The ACME key is stored in `letsencrypt-creds`.


### Containers

The pod consists of three containers, each doing exactly one thing.
They share the filesystem `/var/www/acme-challenge` to store the challenges.

 * **Watcher Container**, `watcher`,
   watches routes and either generates a new certificate or set the already generated certificate.

 * **Cron container**, `cron`,
   periodically checks whether the certificates need to be regenerated.
   When Kubernetes cron jobs are implemented, this will move outside the pod.

 * **Webserver Container**, `nginx`,
   serves `.well-known/acme-challenge` when asking to sign the certificate.
   Uses `ibotty/s2i-nginx` on dockerhub.


## Installing Openshift-Letsencrypt

### Template

Create the template as usual.
```
> oc create -f template.yaml
```

### Deploy openshift-letsencrypt

Instanciate the template.
```
> oc new-app --template=letsencrypt -p LETSENCRYPT_CONTACT_EMAIL=name@example.com
```

### Service Account

The "letsencrypt" service account needs to be able to manage its secrets and manage routes.

```
> oc policy add-role-to-user edit system:serviceaccount:`oc project -q`:letsencrypt
```

### Let's encrypt credentials

Given an account-key (from running [dehydrated](https://github.com/lukas2511/dehydrated) or any other tool), create a secret as follows.

```
> oc secrets new letsencrypt-creds account-key=/path/to/account-key.pem
```

In the future that part should be done by the container itself.


## Notes

### HPKP

It is necessary to pin _at least_ one key to use for disaster recovery, outside the cluster!

Maybe pre-generate `n` keys and pin all of them.
On key rollover, delete the previous key, use the oldest of the remaining keys to sign the certificate, generate a new key and pin the new keys.
That way, the pin can stay valid for `(n-1)* lifetime of a key`.
That is, if no key gets compromised!

### Locking

Should be done with `flock` around `/var/lib/letsencrypt-container/$DOMAINNAME`, whenever a certificate is to be touched.
