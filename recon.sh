#!/bin/bash
: '
	@name   ReconPi recon.sh
	@author Martijn Baalman <@x1m_martijn>
	@link   https://github.com/x1mdev/ReconPi
'


: 'Set the main variables'
YELLOW="\033[1;33m"
GREEN="\033[0;32m"
RESET="\033[0m"
ROOT="$HOME/bugbounty"
FILE=`basename "$0"`
VERSION="0.1.4"
URL=$1


: 'Display the logo'
displayLogo()
{
	echo -e "
__________                          __________.__
\______   \ ____   ____  ____   ____\______   \__|
 |       _// __ \_/ ___\/  _ \ /    \|     ___/  |
 |    |   \  ___/\  \__(  <_> )   |  \    |   |  |
 |____|_  /\___  >\___  >____/|___|  /____|   |__|
        \/     \/     \/           \/
                          v$VERSION - by $YELLOW@x1m_martijn$RESET
	"
}

: 'Display help text when no arguments are given'
checkArguments()
{
	if [[ -z $1 ]]; then
		echo -e "[$GREEN+$RESET] Usage: bash $FILE <domain.tld>"
		exit 1
	fi
}

: 'Check if the current domain has a directory, else make it'
checkDirectory()
{
	if [ ! -d $ROOT ]; then
		echo -e "[$GREEN+$RESET] Making new directory: $GREEN$ROOT$RESET"
		mkdir "$ROOT"
		cd $ROOT
	fi
	if [ ! -d $ROOT/$1 ]; then
		echo -e "[$GREEN+$RESET] Making new directory: $GREEN$ROOT/$1$RESET"
		mkdir -p "$ROOT/$1"
		cd $ROOT/$1
	fi
}

: 'Run Subfinder on the given domain'
runSubfinder()
{
	echo -e "[$GREEN+$RESET] Running Subfinder on $GREEN$1$RESET..."
	# This output needs to be changed to .json
	docker run -v $HOME/.config/subfinder:/root/.config/subfinder -it subfinder -d $1 -nW --silent > $ROOT/$1/$1.txt

	echo -e "[$GREEN+$RESET] Subfinder finished! Writing (sub)domains to $GREEN$ROOT/$1/domains.txt$RESET."
	touch $ROOT/$1/domains.txt
	cat $ROOT/$1/$1.txt | grep -P "([A-Za-z0-9]).*$1" >> $ROOT/$1/domains.txt

	rm -rf $ROOT/$1/$1.txt
}

: 'Run MassDNS on the given domains'
runMassDNS()
{
	echo -e "[$GREEN+$RESET] Starting MassDNS now!"

	#This doesn't work yet because I need to find a way to get the resolved-domains.txt from the host to docker.
	docker run -it massdns -r lists/resolvers.txt -t A -o S -w resolved-domains.txt > $ROOT/$1/massdns.txt

	echo -e "[$GREEN+$RESET] Done!"
}

: 'Check if host is online, then print it'
checkDomainStatus()
{
	echo -e "[$GREEN+$RESET] Checking which domains are online..."

	touch $ROOT/$1/resolved-domains.txt

	while IFS='' read -r line || [[ -n "$line" ]]; do
		if ping -c 1 $(echo $line | tr -d '[:space:]') &> /dev/null
		then
			IP=`getent hosts $1 | cut -d' ' -f1 | head -n 1`
			echo "$(echo $line | tr -d '[:space:]'),$IP"
		fi
	done < $ROOT/$1/domains.txt > $ROOT/$1/resolved-domains.txt

	echo -e "[$GREEN+$RESET] Online domains written to $GREEN$ROOT/$1/resolved-domains.txt$RESET!"
	echo -e "[$GREEN+$RESET] Displaying $GREEN$ROOT/$1/resolved-domains.txt$RESET:"
	cat $ROOT/$1/resolved-domains.txt
}

: 'Convert domains.txt to json (subdomainDB format) + make POST API request with output from subfinder'
convertDomainsFile()
{
	echo -e "[$GREEN+$RESET] Converting $GREEN$ROOT/$1/domains.txt$RESET to an acceptable $GREEN.json$RESET file.."

	#cat $ROOT/$1/domains.txt | grep -P "([A-Za-z0-9]).*$1" >> $ROOT/$1/domains.json
	#echo -e "{\n\"domains\":"; jq -Rs 'split("\n")' < domains.txt; echo -e "}"
	echo -e "{\n\"domains\":"; jq -MRs 'split("\n")' < domains.txt | sed -z 's/,\n  ""//g'; echo -e "}"
	
	# >> $ROOT/$1/domains.json is not enough, it needs to be in /ReconPi/domains.json format
	
	# Post request to dashboard
	curl -X POST -H "Content-Type: application/json"-H "X-Hacking: is Illegal!" -d "@domains.json" http://127.0.0.1:4000/api/domain/:domain

}

: 'Execute the main functions'
displayLogo
checkArguments    $1
checkDirectory    $1
runSubfinder      $1
checkDomainStatus $1
runMassDNS        $1
#convertDomainsFile #$1
