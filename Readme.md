# Automatic Certificates for Openshift Routes

It will manage all `route`s with (by default) `butter.sh/letsencrypt-managed=yes` labels in the project/namespace, it's deployed in.


## Limitations
For now, there are the following limitations.

 * It only supports domain names of length smaller than 64 characters.
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


## Troubleshooting

### Route does not get admitted

Please test, whether DNS is set up correctly. In particular the hostname to get
a certificate for has to point to the router (or the loadbalancer), also from
within the cluster!


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
> oc policy add-role-to-user edit -z letsencrypt
```

### Let's encrypt credentials

#### Register an account key

You can skip that section, if you already use letsencrypt and already have an account key.

Get [dehydrated](https://github.com/lukas2511/dehydrated) and run the following commands.

```shell
> echo CONTACT_EMAIL=test@example.com > my_config
> /path/to/dehydrated -f config --register --accept-terms
```

This will generate a key in `./accounts/*/account_key.pem` and info about it in
`./accounts/*/registration_info.json`.


#### Create the account key secret

Given an account-key, create a secret as follows.

```
> oc create secret generic letsencrypt-creds \
     --from-file=account-key=/path/to/account-key.pem \
     --from-file=registration-info=./accounts/*/registration_info.json
```

The registration info is not strictly necessary.


## Notes

### HPKP

It is necessary to pin _at least_ one key to use for disaster recovery, outside the cluster!

Maybe pre-generate `n` keys and pin all of them.
On key rollover, delete the previous key, use the oldest of the remaining keys to sign the certificate, generate a new key and pin the new keys.
That way, the pin can stay valid for `(n-1)* lifetime of a key`.
That is, if no key gets compromised!
