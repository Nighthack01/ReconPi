#!/bin/bash
: '
@name   ReconPi recon.sh
@author Martijn B <Twitter: @x1m_martijn>
@link   https://github.com/x1mdev/ReconPi
'

: 'Set the main variables'
YELLOW="\033[1;33m"
GREEN="\033[0;32m"
RESET="\033[0m"
domain="$1"
RESULTDIR="$HOME/assets/$domain"
SUBS="$RESULTDIR/subdomains"
VERSION="2.2"
NUCLEISCAN="$RESULTDIR/nucleiscan"


: 'Display the logo'
displayLogo() {
	echo -e "
__________                          __________.__ 
\______   \ ____   ____  ____   ____\______   \__|
 |       _// __ \_/ ___\/  _ \ /    \|     ___/  |
 |    |   \  ___/\  \__(  <_> )   |  \    |   |  |
 |____|_  /\___  >\___  >____/|___|  /____|   |__|
        \/     \/     \/           \/             
                            
			v$VERSION - $YELLOW@x1m_martijn$RESET" 
		}

	: 'Display help text when no arguments are given'
	checkArguments() {
		if [[ -z $domain ]]; then
			echo -e "[$GREEN+$RESET] Usage: recon <domain.tld>"
			exit 1
		fi
	}

checkDirectories() {
		echo -e "[$GREEN+$RESET] Creating directories and grabbing wordlists for $GREEN$domain$RESET.."
		mkdir -p "$RESULTDIR"
		mkdir -p "$SUBS"  "$NUCLEISCAN" 
}

startFunction() {
	tool=$1
	echo -e "[$GREEN+$RESET] Starting $tool"
}


: 'subdomain gathering'
gatherSubdomains() {
	startFunction "sublert"
	echo -e "[$GREEN+$RESET] Checking for existing sublert output, otherwise add it."
	if [ ! -e "$SUBS"/sublert.txt ]; then
		cd "$HOME"/tools/sublert || return
		yes | python3 sublert.py -u "$domain"
		cp "$HOME"/tools/sublert/output/"$domain".txt "$SUBS"/sublert.txt
		cd "$HOME" || return
	else
		cp "$HOME"/tools/sublert/output/"$domain".txt "$SUBS"/sublert.txt
	fi
	echo -e "[$GREEN+$RESET] Done, next."

	startFunction "subfinder"
	"$HOME"/go/bin/subfinder -d "$domain" -all -config "$HOME"/ReconPi/configs/config.yaml -o "$SUBS"/subfinder.txt
	echo -e "[$GREEN+$RESET] Done, next."

	startFunction "assetfinder"
	"$HOME"/go/bin/assetfinder --subs-only "$domain" >"$SUBS"/assetfinder.txt
	echo -e "[$GREEN+$RESET] Done, next."

	startFunction "amass"
	"$HOME"/go/bin/amass enum -passive -d "$domain" -config "$HOME"/ReconPi/configs/config.ini -o "$SUBS"/amassp.txt
	echo -e "[$GREEN+$RESET] Done, next."

	startFunction "findomain"
	findomain -t "$domain" -u "$SUBS"/findomain_subdomains.txt
	echo -e "[$GREEN+$RESET] Done, next."

	startFunction "chaos"
	chaos -d "$domain" -key $CHAOS_KEY -o "$SUBS"/chaos_data.txt
	echo -e "[$GREEN+$RESET] Done, next."

	startFunction "github-subdomains"
	github-subdomains -t $github_subdomains_token -d "$domain" | sort -u >> "$SUBS"/github_subdomains.txt
	echo -e "[$GREEN+$RESET] Done, next."

	startFunction  rapiddns
	crobat -s "$domain" | sort -u | tee "$SUBS"/rapiddns_subdomains.txt
	echo -e "[$GREEN+$RESET] Done, next."

	echo -e "[$GREEN+$RESET] Combining and sorting results.."
	cat "$SUBS"/*.txt | sort -u >"$SUBS"/subdomains
	echo -e "[$GREEN+$RESET] Resolving subdomains.."
	cat "$SUBS"/subdomains | sort -u | shuffledns -silent -d "$domain" -r "$IPS"/resolvers.txt > "$SUBS"/alive_subdomains
	echo -e "[$GREEN+$RESET] Getting alive hosts.."
	cat "$SUBS"/alive_subdomains | "$HOME"/go/bin/httprobe -prefer-https | tee "$SUBS"/hosts
	echo -e "[$GREEN+$RESET] Done."
}

: 'subdomain takeover check'
checkTakeovers() {
	startFunction "subjack"
	"$HOME"/go/bin/subjack -w "$SUBS"/hosts -a -ssl -t 50 -v -c "$HOME"/go/src/github.com/haccer/subjack/fingerprints.json -o "$SUBS"/all-takeover-checks.txt -ssl
	grep -v "Not Vulnerable" <"$SUBS"/all-takeover-checks.txt >"$SUBS"/takeovers
	rm "$SUBS"/all-takeover-checks.txt

	vulnto=$(cat "$SUBS"/takeovers)
	if [[ $vulnto == *i* ]]; then
		echo -e "[$GREEN+$RESET] Possible subdomain takeovers:"
		for line in "$SUBS"/takeovers; do
			echo -e "[$GREEN+$RESET] --> $vulnto "
		done
	else
		echo -e "[$GREEN+$RESET] No takeovers found."
	fi

	startFunction "nuclei to check takeover"
	cat "$SUBS"/hosts | nuclei -t subdomain-takeover/ -c 50 -o "$SUBS"/nuclei-takeover-checks.txt
	vulnto=$(cat "$SUBS"/nuclei-takeover-checks.txt)
	if [[ $vulnto != "" ]]; then
		echo -e "[$GREEN+$RESET] Possible subdomain takeovers:"
		for line in "$SUBS"/nuclei-takeover-checks.txt; do
			echo -e "[$GREEN+$RESET] --> $vulnto "
		done
	else
		echo -e "[$GREEN+$RESET] No takeovers found."
	fi
}



: 'Check for Vulnerabilities'
runNuclei() {
	startFunction  "Nuclei Basic-detections"
	nuclei -l "$SUBS"/hosts -t generic-detections/ -c 50 -H "x-bug-bounty: $hackerhandle" -o "$NUCLEISCAN"/generic-detections.txt
	startFunction  "Nuclei CVEs Detection"
	nuclei -l "$SUBS"/hosts -t cves/ -c 50 -H "x-bug-bounty: $hackerhandle" -o "$NUCLEISCAN"/cve.txt
	startFunction  "Nuclei default-creds Check"
	nuclei -l "$SUBS"/hosts -t default-credentials/ -c 50 -H "x-bug-bounty: $hackerhandle" -o "$NUCLEISCAN"/default-creds.txt
	startFunction  "Nuclei dns check"
	nuclei -l "$SUBS"/hosts -t dns/ -c 50 -H "x-bug-bounty: $hackerhandle" -o "$NUCLEISCAN"/dns.txt
	startFunction  "Nuclei files check"
	nuclei -l "$SUBS"/hosts -t files/ -c 50 -H "x-bug-bounty: $hackerhandle" -o "$NUCLEISCAN"/files.txt
	startFunction  "Nuclei Panels Check"
	nuclei -l "$SUBS"/hosts -t panels/ -c 50 -H "x-bug-bounty: $hackerhandle" -o "$NUCLEISCAN"/panels.txt
	startFunction  "Nuclei Security-misconfiguration Check"
	nuclei -l "$SUBS"/hosts -t security-misconfiguration/ -c 50 -H "x-bug-bounty: $hackerhandle" -o "$NUCLEISCAN"/security-misconfiguration.txt
	startFunction  "Nuclei Technologies Check"
	nuclei -l "$SUBS"/hosts -t technologies/ -c 50 -H "x-bug-bounty: $hackerhandle" -o "$NUCLEISCAN"/technologies.txt
	startFunction  "Nuclei Tokens Check"
	nuclei -l "$SUBS"/hosts -t tokens/ -c 50 -H "x-bug-bounty: $hackerhandle" -o "$NUCLEISCAN"/tokens.txt
	startFunction  "Nuclei Vulnerabilties Check"
	nuclei -l "$SUBS"/hosts -t vulnerabilities/ -c 50 -H "x-bug-bounty: $hackerhandle" -o "$NUCLEISCAN"/vulnerabilties.txt
	echo -e "[$GREEN+$RESET] Nuclei Scan finished"
}



notifyDiscord() {
	startFunction "Trigger Discord Notification"
	intfiles=$(cat $NUCLEISCAN/*.txt | wc -l)

	source "$HOME"/ReconPi/configs/tokens.txt
	export DISCORD_WEBHOOK_URL="$DISCORD_WEBHOOK_URL"

	totalsum=$(cat $SUBS/hosts | wc -l)
	message="**$domain scan completed!\n $totalsum live hosts discovered.**\n"

	if [ -s "$SUBS/takeovers" ]
	then
			posibbletko="$(cat $SUBS/takeovers | wc -l)"
			message+="**Found $posibbletko possible subdomain takeovers.**\n"
	else
			message+="**No subdomain takovers found.**\n"
	fi

	cd $NUCLEISCAN
	for file in *.txt
	do
		if [ -s "$file" ]
		then
			fileName=$(basename ${file%%.*})
			fileNameUpper="$(tr '[:lower:]' '[:upper:]' <<< ${fileName:0:1})${fileName:1}"
			nucleiData="$(jq -Rs . <$file | cut -c 2- | rev | cut -c 2- | rev)"
			message+="**$fileNameUpper discovered:**\n "$nucleiData"\n"
		fi
	done

	python3 $HOME/ReconPi/scripts/webhook_Discord.py <<< $(echo "$message")

	echo -e "[$GREEN+$RESET] Done."
}

: 'Execute the main functions'

source "$HOME"/ReconPi/configs/tokens.txt || return
export SLACK_WEBHOOK_URL="$SLACK_WEBHOOK_URL"

displayLogo
gatherSubdomains
checkTakeovers
runNuclei
notifyDiscord

# Uncomment the functions
