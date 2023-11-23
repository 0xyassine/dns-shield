#!/bin/bash

#AUTHOR: 0xyassine
#FULL DOCUMENTATION: https://blog.byteninja.net/dns-shield-blocklists-updater/

#SOURCE THE VARIABLES
. `dirname $0`/variables.conf

#CREATE THE REQUIRED DIRECTORIES
sudo mkdir -p $BLOCK_LIST_DIR_PATH $TMP_BLOCK_LIST_DIR_PATH

#COLORS
NORMAL='\033[0m'
BLUE="\033[0;34m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
GREEN="\033[0;32m"
GRAY="\033[0;37m"

FINAL_BLOCKLIST_UPDATE=false
FAILED=false

if ! sudo which dnsmasq &> /dev/null;then
	echo -e "${RED}[-] DNSMASQ IS NOT INSTALLED${NORMAL}"
	exit
fi

function send_alert()
{
        MESSAGE=$1
	if $TELEGRAM_BOT_ENABLED;then
		if [ ! -z $BOT_TOKEN ] && [ ! -z $BOT_CHAT_ID ];then
			curl -s -m 50 --data "text=${MESSAGE}" --data "chat_id=${BOT_CHAT_ID}GROUP_ID" 'https://api.telegram.org/bot'${BOT_TOKEN}'/sendMessage' > /dev/null
		fi
	fi
}

function generate_dns_shield_banner()
{
        echo -e ${BLUE}"▓█████▄  ███▄    █   ██████      ██████  ██░ ██  ██▓▓█████  ██▓    ▓█████▄"
	sleep 0.1
        echo -e ${BLUE}"▒██▀ ██▌ ██ ▀█   █ ▒██    ▒    ▒██    ▒ ▓██░ ██▒▓██▒▓█   ▀ ▓██▒    ▒██▀ ██▌"
        sleep 0.1
	echo -e ${BLUE}"░██   █▌▓██  ▀█ ██▒░ ▓██▄      ░ ▓██▄   ▒██▀▀██░▒██▒▒███   ▒██░    ░██   █▌"
        sleep 0.1
	echo -e ${BLUE}"░▓█▄   ▌▓██▒  ▐▌██▒  ▒   ██▒     ▒   ██▒░▓█ ░██ ░██░▒▓█  ▄ ▒██░    ░▓█▄   ▌"
        sleep 0.1
	echo -e ${BLUE}"░▒████▓ ▒██░   ▓██░▒██████▒▒   ▒██████▒▒░▓█▒░██▓░██░░▒████▒░██████▒░▒████▓"
        sleep 0.1
	echo -e ${BLUE}" ▒▒▓  ▒ ░ ▒░   ▒ ▒ ▒ ▒▓▒ ▒ ░   ▒ ▒▓▒ ▒ ░ ▒ ░░▒░▒░▓  ░░ ▒░ ░░ ▒░▓  ░ ▒▒▓  ▒"
	sleep 0.1
	echo -e ${BLUE}" ░ ▒  ▒ ░ ░░   ░ ▒░░ ░▒  ░ ░   ░ ░▒  ░ ░ ▒ ░▒░ ░ ▒ ░ ░ ░  ░░ ░ ▒  ░ ░ ▒  ▒"
        sleep 0.1
	echo -e ${BLUE}" ░ ░  ░    ░   ░ ░ ░  ░  ░     ░  ░  ░   ░  ░░ ░ ▒ ░   ░     ░ ░    ░ ░  ░"
        sleep 0.1
	echo -e ${BLUE}"   ░             ░       ░           ░   ░  ░  ░ ░     ░  ░    ░  ░   ░"
        sleep 0.1
	echo -e ${BLUE}" ░"
	sleep 0.1
	echo -e ${GREEN}"							by: 0xyassine"
	sleep 0.1
	echo -e ${RED}"								 v1.0"${NORMAL}
}

function spinner()
{
	local CATEGORY="$1"
	local DESCRIPTION=$2
	local -a SPIN=("+" "x" "-" "*")
	local INTERVAL=0.1
	while :; do
		for CHAR in "${SPIN[@]}"; do
			printf "\r${GREEN}[%s]${NORMAL} $DESCRIPTION ${RED}$CATEGORY${NORMAL} BLOCKLIST${NORMAL}" "$CHAR"
			sleep "$INTERVAL"
		done
	done
}

function download_list()
{
 	local SOURCE=$1
        local DESTINATION=$2
        #GENERATE THE HEADER
        echo "#$SOURCE" | sudo tee $DESTINATION 1>/dev/null
        #DOWNLOAD THE FILE
        curl -s "$SOURCE" | sudo tee -a $DESTINATION 1>/dev/null
}

function generate_dnsmasq_file()
{
        local HEADER=$1
        local SOURCE=$2
        local DESTINATION=$3
        echo "#$HEADER" | sudo tee $DESTINATION 1>/dev/null
        to_dnsmasq_format "$SOURCE" | sudo tee -a $DESTINATION 1> /dev/null
}

function to_dnsmasq_format()
{
	local SOURCE=$1
	local DESTINATION=$2
	cat "$SOURCE" | grep -vE '(^#|^/|^\|\@|\,|##|\|)' | sed -e 's/#.*//g' | grep -oP '([a-zA-Z0-9-]+((\.|\-)[a-zA-Z0-9-]+)*(\.|\-)[a-zA-Z]{2,})(?=$|\s|\/)' | sed -e 's/\///g' | awk '{if ($0 != "") print "address=/" $0 "/#"}'
	sleep 5
}


function is_empty_list()
{
	local SOURCE=("$@")
	if [ -z $SOURCE ]; then
		return 0
	else
		return 1
	fi
}

function set_variables()
{
        CATEGORY_PATH="$BLOCK_LIST_DIR_PATH/$CATEGORY_NAME"
        CATEGORY_STATUS_DIR="$CATEGORY_PATH/.status"
        CATEGORY_STATUS_FULL_PATH=$CATEGORY_STATUS_DIR/active-block
        ORIGINAL_URL_FORMAT_PATH="$CATEGORY_PATH/original/"
        DNSMASQ_FILE_PATH="$CATEGORY_PATH/dnsmasq/"
        sudo mkdir -p $ORIGINAL_URL_FORMAT_PATH $DNSMASQ_FILE_PATH $CATEGORY_STATUS_DIR
        if ! sudo test -f $CATEGORY_STATUS_FULL_PATH;then sudo touch $CATEGORY_STATUS_FULL_PATH;fi
}

function init_variables()
{
        ACTIVE_BLOCK_LIST=()
        ENTRIES=${GRAY}0${NORMAL}
        URLS_NUMBER=${BLUE}0${NORMAL}
        CATEGORY_STATUS=${RED}"DISABLED"${NORMAL}
}

function set_updated_variables()
{
        CATEGORY_UPDATED=true
        FINAL_BLOCKLIST_UPDATE=true
        CATEGORY_STATUS=${YELLOW}"UPDATED"${NORMAL}
}

function init_files()
{
	#EMTY THE FINAL CATEGORY FILE
	echo -n | sudo tee $DNSMASQ_FILE_PATH/${CATEGORY_NAME}.final
	#EMTY STATUS FILES
	echo -n | sudo tee $CATEGORY_STATUS_DIR/tmp-status
	echo -n | sudo tee $CATEGORY_STATUS_FULL_PATH
}

function generate_filename()
{
	local URL=$1
	local RANDOM_PREFIX=$(head /dev/urandom | tr -dc 0-9 | head -c30)
	FILE_NAME=$(echo "$URL" | awk -v random=$RANDOM_PREFIX -F/ '{print $NF "-" random}')

}

function generate_blocklists_files()
{
	local URL=$1
	local SOURCE=$2
	local DESTINATION=$3
	download_list "$URL" "$SOURCE"
	if sudo test -f $DNSMASQ_FILE_FULL_PATH;then sudo rm -f $DNSMASQ_FILE_FULL_PATH;fi
	generate_dnsmasq_file "$URL" "$SOURCE" "$DESTINATION"
        #UPDATE STATUS
	set_updated_variables
}

#CHECK IF SYNC IS REQUIRED
function is_remote_sync_required()
{
	local URL=$1
	#GET THE FILE NAME
	ORIGINAL_FILE_FULL_PATH=$(sudo grep -rw "$URL" $ORIGINAL_URL_FORMAT_PATH/ | head -n 1 | awk -F: '{print $1}')
	#CHECK LAST MODIFICATION DATE
	LAST_UPDATE_TIME=$(expr `date +%s` - `sudo stat -c %Y $ORIGINAL_FILE_FULL_PATH`)
	THRESHOLD=$(expr 3600 \* $UPDATE_INTERVAL)
	if [ $LAST_UPDATE_TIME -gt $THRESHOLD ]; then
		return 0
	else
		return 1
	fi
}

function generate_live_status_file()
{
        local URL=$1
        #UPDATE THE TMP STATUS FILE
        echo "$URL" | sudo tee -a $CATEGORY_STATUS_DIR/tmp-status 1>/dev/null
        DNSMASQ_FILE_FULL_PATH=$(sudo grep -rw "$URL" $DNSMASQ_FILE_PATH/ | head -n 1 | awk -F: '{print $1}')
        if [ "${#DNSMASQ_FILE_FULL_PATH}" -ne 0 ];then
                ACTIVE_BLOCK_LIST+=("$DNSMASQ_FILE_FULL_PATH ")
        fi
}

function generate_original_dnsmasq_files()
{
	spinner $CATEGORY_NAME "CHECKING" &
	CATEGORY_MODIFIED=false
	CATEGORY_UPDATED=false
	for URL in $(echo ${SOURCE_LIST[@]});do
		generate_filename "$URL"
		DNSMASQ_FILE_FULL_PATH=$(sudo grep -rw "$URL" $DNSMASQ_FILE_PATH/ 2>/dev/null | head -n 1 | awk -F: '{print $1}')
		if ! sudo grep -rqw "$URL" $ORIGINAL_URL_FORMAT_PATH/ ;then
			generate_blocklists_files "$URL" "$ORIGINAL_URL_FORMAT_PATH/$FILE_NAME" "$DNSMASQ_FILE_PATH/$FILE_NAME"
		else
			if is_remote_sync_required "$URL";then
				#RESET FILES
				sudo rm -f $ORIGINAL_FILE_FULL_PATH $DNSMASQ_FILE_FULL_PATH
				generate_blocklists_files "$URL" "$ORIGINAL_FILE_FULL_PATH" "$DNSMASQ_FILE_PATH/$FILE_NAME"
			else
				#CHECK IF DNSMASQ FILE IS FOUND AND GENERATE IT IF NEEDED
				#echo "  [+] Original source is up-to-date"
				if ! sudo grep -rwq "$URL" $DNSMASQ_FILE_PATH/; then
					set_updated_variables
					generate_dnsmasq_file "$URL" "$ORIGINAL_FILE_FULL_PATH" "$DNSMASQ_FILE_PATH/$FILE_NAME"
				else
					#echo " [+] DNS FILE UP-TO-DATE"
					CATEGORY_STATUS=${GREEN}"UP-TO-DATE"${NORMAL}
				fi
			fi
		fi
		generate_live_status_file "$URL"
	done
	kill "$!"
	printf "\r${GREEN}[+]${NORMAL} CHECKING ${RED}$CATEGORY_NAME${NORMAL} BLOCKLIST${NORMAL} ${GREEN}DONE${NORMAL}\n"
}

function generate_final_category_list()
{
	#IF NO LIVE BLOCKING, CLEAR FINAL LIST
	if ! sudo test -f $CATEGORY_STATUS_DIR/tmp-status;then sudo touch $CATEGORY_STATUS_DIR/tmp-status;fi
	if ! sudo test -f $CATEGORY_STATUS_FULL_PATH;then sudo touch $CATEGORY_STATUS_FULL_PATH;fi
	if [ $(sudo cat $CATEGORY_STATUS_DIR/tmp-status | wc -l ) -eq 0 ];then
		echo -n | sudo tee $DNSMASQ_FILE_PATH/${CATEGORY_NAME}.final
	fi
	for NEW_BLOCKED_URL in $(sudo cat $CATEGORY_STATUS_DIR/tmp-status);do
		if ! sudo grep -wq $NEW_BLOCKED_URL $CATEGORY_STATUS_FULL_PATH;then
			set_updated_variables
		fi
	done
	#IF THE OLD AND THE NEW BLOCKLIST ARE NOT IDENTICAL, SET STATUS TO MODIFIED
	if [ $(sudo cat $CATEGORY_STATUS_DIR/tmp-status |wc -l) -ne $(sudo cat $CATEGORY_STATUS_FULL_PATH |wc -l) ];then
		set_updated_variables
	fi
	#UPDATE CURRENT STATUS
	sudo mv $CATEGORY_STATUS_DIR/tmp-status $CATEGORY_STATUS_FULL_PATH
	#GENERATE FINAL LIST
	if [ ${#ACTIVE_BLOCK_LIST[@]} -eq 0 ];then sudo touch $DNSMASQ_FILE_PATH/${CATEGORY_NAME}.final;fi
	if [ $CATEGORY_MODIFIED = true ] || [ $CATEGORY_UPDATED = true ];then
		if [[ ${#ACTIVE_BLOCK_LIST[@]} -ne 0 ]];then
			sudo cat ${ACTIVE_BLOCK_LIST[@]} | grep -E '^[^#]' | sudo tee $DNSMASQ_FILE_PATH/${CATEGORY_NAME}.final 1>/dev/null
		else
			echo -n | sudo tee $DNSMASQ_FILE_PATH/${CATEGORY_NAME}.final
		fi
	else
		if ! sudo test -f $DNSMASQ_FILE_PATH/${CATEGORY_NAME}.final;then
			sudo cat ${ACTIVE_BLOCK_LIST[@]} | grep -E '^[^#]' | sudo tee $DNSMASQ_FILE_PATH/${CATEGORY_NAME}.final 1>/dev/null
			CATEGORY_STATUS=${YELLOW}"UPDATED"${NORMAL}
		fi
		CATEGORY_STATUS=${GREEN}"UP-TO-DATE"${NORMAL}
	fi
	if is_empty_list "${SOURCE_LIST[@]}";then
		CATEGORY_STATUS=${RED}"DISABLED"${NORMAL}
		echo -e "$CATEGORY_NAME|$URLS_NUMBER|$CATEGORY_STATUS|$ENTRIES" | column -t >> $TEMP_TABLE
	else
		ENTRIES=${GRAY}$(cat $DNSMASQ_FILE_PATH/${CATEGORY_NAME}.final |wc -l)${NORMAL}
		URLS_NUMBER=${BLUE}${#ACTIVE_BLOCK_LIST[@]}${NORMAL}
		echo -e "$CATEGORY_NAME|$URLS_NUMBER|$CATEGORY_STATUS|$ENTRIES" | column -t >> $TEMP_TABLE
	fi
}

#RESTORE OLD BLOCKLIST IF DNSMASQ FAIL
function restore_old_blocklist()
{
	if sudo test -f ${FINAL_BLOCKLIST_PATH}.`date "+%d-%m-%y"`;then
		sudo mv ${FINAL_BLOCKLIST_PATH}.`date "+%d-%m-%y"` $FINAL_BLOCKLIST_PATH
	else
		return
	fi
	if sudo dnsmasq --test &> /dev/null;then
		if ! sudo service dnsmasq restart;then
			send_alert "DNSMASQ FAILED TO RESTART AFTER RESTORING THE PREVIOUS BLOCK LIST"
			echo -e "${RED}[-] DNSMASQ FAILED TO RESTART AFTER RESTORING THE PREVIOUS BLOCK LIST${NORMAL}"
		else
			ENTRIES=$(cat $FINAL_BLOCKLIST_PATH |wc -l)
			send_alert "PREVIOUS BLOCK LIST HAS BEEN RESTORED WITH $ENTRIES ENTRIES"
			echo -e "${GREEN}[+] PREVIOUS BLOCKLIST HAS BEEN RESTORED${NORMAL}"
		fi
	else
		send_alert "DNSMASQ RETURNED SYNTAX ERROR AFTER RESTORING THE BLOCK LIST"
		echo -e "${RED}[-] DNSMASQ RETURNED SYNTAX ERROR AFTER RESTORING THE BLOCK LIST${NORMAL}"
	fi

}

function generate_final_blocklist()
{
	#echo -e "${GREEN}[+]${NORMAL} GENERATING ${RED}FINAL${NORMAL} BLOCKLIST"
	spinner "FINAL" "GENERATING" &
	FINAL_BLOCKLIST_STATUS=${YELLOW}"UPDATED"${NORMAL}
	sudo cat $BLOCK_LIST_DIR_PATH/*/dnsmasq/*.final | sort -u | grep -Ev '(.*\-\..*|.*\.\-.*|.*\-\-.*|address\=\/(\-|\_))' | grep -E '^address\=.*\/\#$' | sudo tee -a $TMP_BLOCK_LIST_DIR_PATH/$FINAL_BLOCKLIST_NAME 1> /dev/null
	if [ -s $TMP_BLOCK_LIST_DIR_PATH/$FINAL_BLOCKLIST_NAME ];then
		#BACKUP OLD BLOCK LIST
		if sudo test -f $FINAL_BLOCKLIST_PATH ;then sudo mv $FINAL_BLOCKLIST_PATH ${FINAL_BLOCKLIST_PATH}.`date "+%d-%m-%y"`;fi
		#INSTALL THE NEW BLOCK LIST
		sudo mv $TMP_BLOCK_LIST_DIR_PATH/$FINAL_BLOCKLIST_NAME $FINAL_BLOCKLIST_PATH
	fi
	#REMOVE THE TEMP DIRECTORY
	sudo rm -rf $TMP_BLOCK_LIST_DIR_PATH
	#SEND ALERT IF DNSMASQ FAILED AFTER UPDATING THE BLOCK LIST
	if sudo dnsmasq --test &> /dev/null;then
		if ! sudo service dnsmasq restart;then
			send_alert "DNSMASQ FAILED TO RESTART AFTER ADDING THE BLOCK LIST"
			echo -e "${RED}[-] DNSMASQ FILED TO RESTART AFTER ADDING THE BLOCK LIST${NORMAL}"
			FAILED=true
		else
			echo -e "${GREEN}[+] DNSMASQ IS UP AND RUNNING${NORMAL}"
		fi
	else
		send_alert "DNSMASQ FAILED AFTER UPDATING THE BLOCK LIST, OLD BLOCKLIST WILL BE RESTORED"
		echo -e "${RED}[-] DNSMASQ FAILED AFTER UPDATING THE BLOCK LIST, OLD BLOCKLIST WILL BE RESTORED${NORMAL}"
		FAILED=true
	fi
	kill "$!"
	printf "\r${GREEN}[+]${NORMAL} GENERATING ${RED}FINAL${NORMAL} BLOCKLIST${NORMAL} ${GREEN}DONE${NORMAL}\n"
}

function configure_category()
{
        CATEGORY_NAME=${!#}
	local SOURCE_LIST=("${@:1:$#-1}")
	#INIT THE VARIABLES
	set_variables
	init_variables
	#DOWNLOAD SOURCE AND GENERATE DNSMASQ FILES WHEN NEEDED
	generate_original_dnsmasq_files
	#GENERATE FINAL CATEGORY LIST
	generate_final_category_list
}

echo ''
generate_dns_shield_banner
echo ''

#TABLE HEADER
TEMP_TABLE="/tmp/.temp-table"
echo -e "CATEGORY|SOURCES|STATUS|DOMAINS" | column -t > $TEMP_TABLE

#CONFIGURE CATEGORIES
configure_category "${ADS_LISTS[@]}" "ADS"
configure_category "${TRACKING_LISTS[@]}" "TRACKING"
configure_category "${PORN_LISTS[@]}" "PORN"
configure_category "${MALWARE_LISTS[@]}" "MALWARE"
configure_category "${OTHER_LISTS[@]}" "OTHERS"

if $FINAL_BLOCKLIST_UPDATE;then
	generate_final_blocklist
	if $FAILED;then
		restore_old_blocklist
	else
		sudo rm ${FINAL_BLOCKLIST_PATH}.`date "+%d-%m-%y"`
		ENTRIES=${RED}$(sudo cat $FINAL_BLOCKLIST_PATH| wc -l)${NORMAL}
	fi
else
	if ! sudo test -f $FINAL_BLOCKLIST_PATH;then
		generate_final_blocklist
		FINAL_BLOCKLIST_STATUS=${BLUE}"GENERATED"${NORMAL}
	else
		FINAL_BLOCKLIST_STATUS=${GREEN}"UP-TO-DATE"${NORMAL}
	fi
	ENTRIES=${RED}$(sudo cat $FINAL_BLOCKLIST_PATH| wc -l)${NORMAL}
fi

echo -e "${GREEN}[+]${NORMAL} GENERATING STATISTICS"
echo ""
echo -e "final_list||$FINAL_BLOCKLIST_STATUS|$ENTRIES" | column -t >> $TEMP_TABLE
cat $TEMP_TABLE | column -t -s "|"
echo ""
rm -f $TEMP_TABLE

if ! $FAILED;then
	if sudo systemctl is-active dnsmasq &> /dev/null;then
		echo -e "${GREEN}[+] DNSMASQ IS UP AND RUNNING${NORMAL}"
	else
		echo -e "${RED}[-] DNSMASQ IS NOT RUNNING${NORMAL}"
	fi
fi
