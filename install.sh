#!/bin/bash
: '
@name   ReconPi install.sh
@author Martijn B <Twitter: @x1m_martijn>
@link   https://github.com/x1mdev/ReconPi
'

: 'Set the main variables'
YELLOW="\033[133m"
GREEN="\033[032m"
RESET="\033[0m"
VERSION="2.2"

: 'Display the logo'
displayLogo() {
	clear
	echo -e "
__________                          __________.__ 
\______   \ ____   ____  ____   ____\______   \__|
 |       _// __ \_/ ___\/  _ \ /    \|     ___/  |
 |    |   \  ___/\  \__(  <_> )   |  \    |   |  |
 |____|_  /\___  >\___  >____/|___|  /____|   |__|
        \/     \/     \/           \/             
                            
			v$VERSION - $YELLOW@x1m_martijn$RESET"
		}

	: 'Basic requirements'
	basicRequirements() {
		echo -e "[$GREEN+$RESET] This script will install the required dependencies to run recon.sh, please stand by.."
		echo -e "[$GREEN+$RESET] It will take a while, go grab a cup of coffee :)"
		cd "$HOME" || return
		sleep 1
		echo -e "[$GREEN+$RESET] Getting the basics.."
		export LANGUAGE=en_US.UTF-8
		export LANG=en_US.UTF-8
		export LC_ALL=en_US.UTF-8
		sudo apt-get update -y
		sudo apt-get install git -y
		git clone https://github.com/x1mdev/ReconPi.git
		sudo apt-get install -y --reinstall build-essential
		sudo apt install -y python3-pip
		sudo apt install -y file
		sudo apt-get install -y dnsutils
		sudo apt install -y lua5.1 alsa-utils libpq5
		sudo apt-get autoremove -y
		sudo apt clean
		#echo -e "[$GREEN+$RESET] Stopping Docker service.."
		#sudo systemctl disable docker.service
		#sudo systemctl disable docker.socket
		echo -e "[$GREEN+$RESET] Creating directories.."
		mkdir -p "$HOME"/tools
		mkdir -p "$HOME"/go
		mkdir -p "$HOME"/go/src
		mkdir -p "$HOME"/go/bin
		mkdir -p "$HOME"/go/pkg
		sudo chmod u+w .
		echo -e "[$GREEN+$RESET] Done."
	}

: 'Golang initials'
golangInstall() {
	echo -e "[$GREEN+$RESET] Installing and setting up Go.."

	if [[ $(go version | grep -o '1.14') == 1.14 ]]; then
		echo -e "[$GREEN+$RESET] Go is already installed, skipping installation"
	else
		cd "$HOME"/tools || return
		git clone https://github.com/udhos/update-golang
		cd "$HOME"/tools/update-golang || return
		sudo bash update-golang.sh
		sudo cp /usr/local/go/bin/go /usr/bin/ 
		echo -e "[$GREEN+$RESET] Done."
	fi

	echo -e "[$GREEN+$RESET] Adding recon alias & Golang to "$HOME"/.bashrc.."
	sleep 1
	configfile="$HOME"/.bashrc

	if [ "$(cat "$configfile" | grep '^export GOPATH=')" == "" ]; then
		echo export GOPATH='$HOME'/go >>"$HOME"/.bashrc
	fi

	if [ "$(echo $PATH | grep $GOPATH)" == "" ]; then
		echo export PATH='$PATH:$GOPATH'/bin >>"$HOME"/.bashrc
	fi

	if [ "$(cat "$configfile" | grep '^alias recon=')" == "" ]; then
		echo "alias recon=$HOME/ReconPi/recon.sh" >>"$HOME"/.bashrc
	fi

	bash /etc/profile.d/golang_path.sh

	source "$HOME"/.bashrc

	cd "$HOME" || return
	echo -e "[$GREEN+$RESET] Golang has been configured."
}

: 'Golang tools'
golangTools() {
	echo -e "[$GREEN+$RESET] Installing subfinder.."
	GO111MODULE=on go get -u -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder
	echo -e "[$GREEN+$RESET] Done."

	echo -e "[$GREEN+$RESET] Installing assetfinder.."
	go get -u -v github.com/tomnomnom/assetfinder
	echo -e "[$GREEN+$RESET] Done."

	echo -e "[$GREEN+$RESET] Installing gf.."
	go get -u -v github.com/tomnomnom/gf
	echo 'source $GOPATH/src/github.com/tomnomnom/gf/gf-completion.bash' >> ~/.bashrc
	cp -r $GOPATH/src/github.com/tomnomnom/gf/examples ~/.gf
	cd "$HOME"/tools/ || return
	git clone https://github.com/1ndianl33t/Gf-Patterns
	cp ~/Gf-Patterns/*.json ~/.gf
	git clone https://github.com/dwisiswant0/gf-secrets
	cp "$HOME"/tools/gf-secrets/.gf/*.json ~/.gf
	echo -e "[$GREEN+$RESET] Done."

	echo -e "[$GREEN+$RESET] Installing ffuf (Fast web fuzzer).."
	go get -u -v github.com/ffuf/ffuf
	echo -e "[$GREEN+$RESET] Done."

	echo -e "[$GREEN+$RESET] Installing gobuster.."
	go get -u -v github.com/OJ/gobuster
	echo -e "[$GREEN+$RESET] Done."

	echo -e "[$GREEN+$RESET] Installing nuclei.."
	GO111MODULE=on go get -u -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei
	echo -e "[$GREEN+$RESET] Done."


        echo -e "[$GREEN+$RESET] Installing httpx"
	GO111MODULE=on go get -u -v github.com/projectdiscovery/httpx/cmd/httpx
	echo -e "[$GREEN+$RESET] Done."

}

: 'Additional tools'
additionalTools() {
	echo -e "[$GREEN+$RESET] Installing nuclei-templates.."
	nuclei -update-templates
	echo -e "[$GREEN+$RESET] Done."
	
}

: 'Finalize'
finalizeSetup() {
	echo -e "[$GREEN+$RESET] Finishing up.."
	displayLogo
	source "$HOME"/.bashrc || return
	echo -e "[$GREEN+$RESET] Installation script finished! "
}

: 'Execute the main functions'
displayLogo
basicRequirements
golangInstall
golangTools
additionalTools
setupDashboard
finalizeSetup
