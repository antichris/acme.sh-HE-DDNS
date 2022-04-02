#!/bin/sh

## This Source Code Form is subject to the terms of the Mozilla Public
## License, v. 2.0. If a copy of the MPL was not distributed with this
## file, You can obtain one at http://mozilla.org/MPL/2.0/

heDDNSabout() {
	cat <<-***
Hurricane Electric Dynamic DNS support for acme.sh.

This plugin shields your Hurricane Electric DNS zones in case the host that you
use to acquire certificates is compromised, since the DDNS access key can only
be used to alter the value of the single ACME challenge TXT entry — unlike your
dns.he.net login credentials that provide full control over all your DNS zones.

The DDNS access keys can be set by exporting environment variables corresponding
to each domain, e.g., for "my-domain.tld" run:

  export HE_DDNSKey_my_DASH_domain_DOT_tld='#cGFzc3dvcmQx!'

This is only needed on the first run for each domain, from then on the access
keys are stored in a config, and environment variables are no longer required.

To see the names of the environment variables that should be exported to set the
DDNS access keys, execute this script passing it the domain names, e.g.:

	$(
		s=' *.example.com _acme-challenge.my-domain.tld'
		printf '  $ %s %s\n' "$0" "$s"
		for d in $s; do
			printf '  %s\n' "$(ddnsKeyVar "$d")"
		done
	)

	***
}

## Set DDNS TXT record for the given domain to the given value.
dns_he_d_add() ( ## (domain, txtvalue)
	domain=$(prefixAcme "$1")
	txtValue=$2
	_debug2 domain "$domain"

	ddnsKey=$(loadDDNSKey "$domain") || return
	setDDNSTXT "$domain" "$txtValue" "$ddnsKey"
)

## Display TXT record removal instructions for the given domain.
dns_he_d_rm() { ## (domain)
	_info "$(cat <<-***
The DDNS API does not support record removal.

If you do not intend to use Hurricane Electric DDNS for the ACME challenge any
longer, you may go to the DNS Management dashboard at <https://dns.he.net/> and
manually remove the TXT entry for "$(prefixAcme "$1")".
	***
	)"
}

## Utilities.

## Ensure that the domain has "_acme-challenge." prefix.
prefixAcme() ( ## (domain)
	domain=$1
	p=_acme-challenge
	if [ "${domain##"$p."*}" ]; then
		domain="${p}.${domain#.}"
	fi
	printf %s "$domain"
)

loadDDNSKey() ( ## (domain)
	domain=$1
	keyVar=$(ddnsKeyVar "$domain")

	eval 'DDNSKey="${'"$keyVar"':=$(_readaccountconf "$keyVar")}"'
	if [ ! "$DDNSKey" ]; then
		_err "Missing DDNS access key for '${domain}'"
		_debug "$(ensureMsg "$domain")"
		return 1
	fi

	_saveaccountconf "$keyVar" "$DDNSKey"
	printf %s "$DDNSKey"
)

## Attempt setting the ACME challenge token.
setDDNSTXT() ( ## (domain, txtValue, ddnsKey)
	domain=$1
	txtValue=$2
	ddnsKey=$3
	_debug2 ddnsKey "$ddnsKey"

	body=$(cat <<-***
		password=$(printf %s "$ddnsKey" | _url_encode)
		hostname=$domain
		txt=$txtValue
	***
	)

	url=https://dyn.dns.he.net/nic/update
	resp=$(_post "$(printf %s "$body" | tr '\n' '&')" "$url")
	err=$?
	_debug2 response "$resp"
	[ "$err" != 0 ] && return "$err" ## A transport error, nothing to do here.

	case "$resp" in
	good*) ## Guess what
		return 0
	;;
	badauth)
		_err "Authentication failed for '${domain}'"
		_debug "$(ensureMsg "$domain")"
		return 1
	;;
	nochg\ \"*\")
		_info 'Current TXT value is already valid'
		return 0
	;;
	*)
		_err "$(printf 'Failed to parse the response:\n"%s"' "$resp")"
		return 1
	;;
	esac
)

## Instructions for adding a DDNS TXT record.
ensureMsg() ( ## (domain)
	cat <<-***
Please ensure that the corresponding TXT entry is present in the relevant zone
and has DDNS enabled in the Hurricane Electric DNS Management dashboard at
<https://dns.he.net/>, and export its current access key value as a system
environment variable, e.g.:

  export $(ddnsKeyVar "$1")='\$cGFzc3dvcmQx*'
	***
)

## Output the variable name for DDNS access key for the given domain.
ddnsKeyVar() { ## (domain)
	printf 'HE_DDNSKey_%s' "$(escapeChars "$(stripPrefixes "$1")")"
}

## Convert the argument to lowercase and replace dots, dashes and any
## other character that shell variable names cannot have.
##
## RFC 1034 specifies that valid domain names may only contain ASCII
## letters A through Z, digits 0 through 9 and hyphen, and are to be
## compared in case-insensitive manner. Even though underscore is not
## allowed in hostnames, it may be used in other DNS names, so, since it
## is valid in shell variable names, it is left as is.
escapeChars() { ## (domain)
	printf %s "$1" \
		| tr '[:upper:]' '[:lower:]' \
		| sed '
			s/\./_DOT_/g;
			s/-/_DASH_/g;
			s/[^0-9A-Za-z_]/X/g;
		'
}


## Strip ACME challenge and/or wildcard prefixes from the given domain.
stripPrefixes() { ## (domain)
	stripWildcard "$(stripACMEPrefix "$1")"
}
## Strip the "_acme-challenge." prefix from the given domain.
stripACMEPrefix() { ## (domain)
	printf %s "${1#_acme-challenge.}"
}
## Strip the "*." wildcard prefix from the given domain.
stripWildcard() { ## (domain)
	printf %s "${1#\*.}"
}

# : <<-***
# [Day Mon DD HH:MM:SS TZone Year] ...
# ***

## XXX For testing/debugging purposes.
heDDNSSim() {
	_readaccountconf() {
		dump _readaccountconf "$@"
		printf %s "${storedKey-}"
	}
	_post() {
		dump _post "$@";
		printf %s "${postResp-}"
	}
	_url_encode() (
		v=$(cat)
		dump _url_encode "$v";
		printf pretend-url-encoded:%s "$v"
	)
	_saveaccountconf() { dump _saveaccountconf "$@"; }
	_info() { dump _info "$@"; }
	_err() { dump _err "$@"; }
	_debug() { dump _debug "$@"; }
	_debug2() { dump _debug2 "$@"; }

	dump() {
		printf %s:\\t "$1" >&2
		shift
		for arg; do
			printf " '%s'" "$arg" >&2
		done
		printf \\n >&2
	}

	op=$2
	shift 2
	case "$op" in
	add)
		dns_he_d_add "$@"
	;;
	rm)
		dns_he_d_rm "$@"
	;;
	*)
		printf 'cannot simulate: unknown op: "%s"\n' "$op"
		exit 1
	;;
	esac
}

## Main CLI routine, invoked when this script is executed stand-alone.
heDDNScli() { ## ([domain ...])
	hasArgValues=
	for arg; do
		if [ "$arg" ]; then
			hasArgValues=1
			break
		fi
	done
	if [ ! "$hasArgValues" ]; then
		heDDNSabout
		exit
	fi
	for arg; do
		if [ "$arg" = --help ] || [ "$arg" = -h ]; then
			heDDNSabout
			exit
		fi
	done
	## XXX For testing/debugging purposes.
	if [ "$1" = --sim ]; then
		heDDNSSim "$@"
		exit
	fi

	for arg; do
		printf %s\\n "$(ddnsKeyVar "$arg")"
	done
}

[ "$(basename "$0")" != dns_he_d.sh ] || heDDNScli "$@"
