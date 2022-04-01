# Hurricane Electric Dynamic DNS support for acme.sh

This plugin provides a secure way to perform [ACME DNS-01 challenges][DNS-01] by using the Hurricane Electric Dynamic DNS features.

It shields your DNS zones in case the host that you use to acquire certificates is compromised, since the DDNS access key can only be used to alter the value of the single ACME challenge TXT entry — [unlike] your `dns.he.net` login credentials that provide full control over all your DNS zones.


## Installation

Download the `dns_he_d.sh` script from the [latest release][latest] and put it either

- in the acme.sh home directory (`.acme.sh/`) or
- in the `dnsapi` sub-directory (`.acme.sh/dnsapi/`).


## Operation

Unlike other acme.sh DNS API providers, this plugin does not go poking around your DNS zones, so you have to manually [add the TXT records](#adding-txt-records) once before you can automate issuing certificates.

When you have the TXT records set up for dynamic DNS, export system environment variables [corresponding to each domain](#getting-ddns-key-variable-names) with their respective DDNS access keys, e.g.:

```sh
export HE_DDNSKey_example_DOT_com='#cGFzc3dvcmQx!'
export HE_DDNSKey_www_DOT_example_DOT_com='*ZGlmZmVyZW50&'
```

Request the certificate by executing

```sh
acme.sh --dns dns_he_d --issue -d example.com -d www.example.com
```

The access keys are saved to `~/.acme.sh/account.conf` and will be reused as needed.


### Adding TXT records

In order to use dynamic DNS for ACME challenges, you first have to add the corresponding TXT records to your zones and enable DDNS for each of them in the Hurricane Electric DNS Management dashboard at <https://dns.he.net/>.

You can add the ACME challenge TXT records simply prefixing the domain name (or replacing the wildcard for wildcard domains) with `_acme-challenge`:

|       Domain name |                   TXT record name |
|------------------:|----------------------------------:|
| `www.example.com` | `_acme-challenge.www.example.com` |
|     `example.com` |     `_acme-challenge.example.com` |
|   `*.example.com` |     `_acme-challenge.example.com` |

If you're uncertain, you can start by running

```sh
acme.sh --dns dns_he_d --issue -d example.com -d www.example.com --staging
```

the error message will tell you precisely what is the name of the TXT record that you have to add.

Each TXT record that you add must also be enabled for dynamic DNS. That's pretty straightforward: just check the corresponding checkbox in the record editing dialog.

Remember to also set (generate) DDNS access keys for each of the records.


### Getting DDNS key variable names

You can execute the `dns_he_d.sh` script passing it the domain names to get the environment variable names that should be exported to set the DDNS access keys, e.g.:

```sh
$ ~/.acme.sh/dnsapi/dns_he_d.sh *.example.com _acme-challenge.my-domain.tld
HE_DDNSKey_example_DOT_com
HE_DDNSKey_my_DASH_domain_DOT_tld
```


## License

The source code of this project is released under [Mozilla Public License Version 2.0][MPL]. See [LICENSE](LICENSE).

[unlike]: https://github.com/acmesh-official/acme.sh/wiki/dnsapi#31-use-hurricane-electric
	"dnsapi · acmesh-official/acme.sh Wiki"

[latest]: https://github.com/antichris/acme.sh-HE-DDNS/releases/latest
	"Latest of Releases · antichris/acme.sh-HE-DDNS"

[DNS-01]: https://letsencrypt.org/docs/challenge-types/#dns-01-challenge
	"DNS-01 challenge - Challenge Types - Let's Encrypt"

[MPL]: https://www.mozilla.org/en-US/MPL/2.0/
	"Mozilla Public License, version 2.0"
