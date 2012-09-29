#!/bin/bash
# Script for adding users and viewing them
# Author: zeande

adminEmail="zechariah.andersen@gmail.com"
adminSignature="Zech Andersen\nNDSU ACM Chair\nhttp://ndacm.org/\nACM HQ:IACC 162"

########################################################
menu="Select an option:\n   1) Add User\n   2) View Users\n   3) Purge Users\n   0) Exit"
	#Select an option:
 	#   1) Add User
	#   2) View Users
	#   3) Purge Users
	#   0) Exit
#########################################################
_continue() {
	read -p "Press enter to continue..."
}
quit="no"
main() {
	clear=yes
	while [ $quit != "yes" ]
	do
		if [ $clear = "yes" ]
		then
			clear
			echo "<<<ACM User Admin Script>>>"
		fi
		clear=yes
		echo -e $menu
		read -p "Input : " option
		echo
		case $option in
			1 )
			  validType="no"
			  while [ $validType != "yes" ]
			  do
				echo
				echo "What type of account is this?"
				echo "  1) ACM Member"
				echo "  2) Web Account"
				echo -n " input : "
				validType="yes"
				read type
				case $type in
					1 )
					  checkUser ;;
					2 )
					  webAccount ;;
					* )
					  validType="no"
				esac
			  done ;;
			2 )
			  viewUsers ;;
			3 )
			  purgeUsers ;;
			0 )
			  quit="yes" ;;
			* )
			  echo "Invalid input!"; clear=no
		esac
	done
}

checkUser() {
	echo -n "Enter students first and last name"
	read -p "  > "  name
	name=`echo "$name" | sed -e 's/ /*/g'`

	# Searhces for user in NDSU LDAP directory and returns it in the format  uid,LastName,FirstName,Email
#	results="$(ldapsearch -xLLL -h ldap.ndsu.nodak.edu -b dc=ndsu,dc=nodak,dc=edu cn=$name givenName sn mailRoutingAddress uid | egrep -v 'dn: ' | grep : | sed ':a;N;$!ba;s/\n/,/g' | sed -e 's/uid: /\nuid: /g' | sed -e 's/[a-zA-Z]\+: //g' | sed -e 's/,$//g' )"
	results="$(ldapsearch -xLLL -h ldap.ndsu.nodak.edu -b dc=ndsu,dc=nodak,dc=edu cn=$name givenName sn mailRoutingAddress uid | egrep -v 'dn: ' | grep :)"
	uids=($(echo "$results" | grep uid: | sed -e 's/[a-zA-Z]\+: //g' |  cut -d, -f 1))    #array of user ids
	sns=($(echo "$results" | grep sn: | sed -e 's/[a-zA-Z]\+: //g' |  cut -d, -f 2))     #array of surnames
	gns=($(echo "$results" | grep givenName: | sed -e 's/[a-zA-Z]\+: //g' | cut -d, -f 3))     #array of GivenNames
	emails=($(echo "$results" | grep mailRoutingAddress: | sed -e 's/[a-zA-Z]\+: //g' | cut -d, -f 4))  #array of emails
	if [ ${#results} -eq 0 ]
	then
		echo -e "\nFail: Student not found in the LDAP directory!"
		read -p "Enter 'm' to manually enter data > " input
		if [ $input = "m" ]
		then
			manEntry
		fi
		return
	elif [ ${#emails[@]} -eq 1 ]
	then
		echo "Success: Student has been found in the LDAP directory!"
		echo "   Name:  $gns $sns"
		echo "   Email: $emails"
		echo "   uid:   $uids"
		echo
		createUser $gns $sns $emails $uids
	else
		echo "Multiple students found matching that name."
		choice=-1
		choices=$[${#uids[@]}-1] # Choices gets the value that is 1 less than the number of students found above.
		while [ $choice -lt 0 -o $choice -gt $choices ]
		do
			echo
			echo "Choose the correct student: "
			for i in `seq 0 $choices`
			do
				echo "   $i) Email: ${emails[$i]}"
				echo  "      Uid:   ${uids[$i]}"
				echo
			done
			read -p "Enter choice (0-$choices): " choice
			choice=$(echo $choice | sed -e 's/[^0-9]//g')
		done
		createUser ${gns[$choice]} ${sns[$choice]} ${emails[$choice]} ${uids[$choice]}
	fi
	_continue
}

viewUsers() {
	:
}

purgeUsers() {
	:
}

# $1 - First name
# $2 - Last name
# $3 - Email
# $4 - username
createUser() {
	today=$(date +%Y-%m-%d)
	expires=$(date -d "$today 365 days" +%Y-%m-%d) # Add 365 days to today.
	exists=$(ldapsearch -xLLL -h localhost -b dc=acm,dc=ndsu,dc=nodak,dc=edu uid=$4 | wc -l)
	shell="/bin/bash"
	read -p "Has user paid membership dues (y/n) > " paid
	if [ $paid != "y" -a $paid != "Y" ]
	then
		paid="n"
		expires=$today
		shell="/bin/expired"
	fi

	if [ $exists -gt 0 ]
	then
		if [ $paid = "n" ]
		then
			return 1
		fi
		echo "User $4 exists. Renewing account..."
		today=$(date +%Y-%m-%d)
		_ldapmodify $4 accountExpires $expires || echo -e "\nError renewing $4\'s account!"
		_ldapmodify $4 loginShell "/bin/bash" || echo -e "\nError updating user's shell!"
		return 1
	fi

	echo "Are you sure you want to add $1 $2 to the ACM LDAP directory?"
	read -p "(y/N) > " response
	if [ $response != "y" -a $response != "Y" ]
	then
		echo "Request cancelled, returning to main menu..."
		sleep 1s
		return
	fi
	echo "Adding $gns $sns to LDAP directory..."
	. /etc/ldapscripts/ldapscripts.conf
	. /usr/share/ldapscripts/runtime
	homedir=$(echo $UHOMES | sed -e "s/%u/$4/g")
	password=$(randpass 10 0)
	addUserString="dn: uid=$4,$USUFFIX,$SUFFIX\n"
	addUserString=$addUserString"objectClass: ExpirationAttrs\n"
	addUserString=$addUserString"objectClass: inetOrgPerson\n"
	addUserString=$addUserString"objectClass: posixAccount\n"
	addUserString=$addUserString"objectClass: shadowAccount\n"
	addUserString=$addUserString"uid: $4\n"
	addUserString=$addUserString"sn: $2\n"
	addUserString=$addUserString"givenName: $1\n"
	addUserString=$addUserString"cn: $1 $2\n"
	addUserString=$addUserString"email: $3\n"
	addUserString=$addUserString"accountCreated: $today\n"
	addUserString=$addUserString"accountExpires: $expires\n"
	addUserString=$addUserString"uidNumber: $(_findnextuid)\n"
	addUserString=$addUserString"gidNumber: $(_findnextgid)\n"
	addUserString=$addUserString"userPassword: $password\n"
	addUserString=$addUserString"gecos: $1 $2\n"
	addUserString=$addUserString"loginShell: $shell\n"
	addUserString=$addUserString"homeDirectory: $homedir\n"
	addUserString=$addUserString"description: User account for $1 $2"
	(echo -e $addUserString | ldapadd -y $BINDPWDFILE -D $BINDDN -xH $SERVER && ldapaddgroup $4 ) || (echo -e "\nError adding $4's account!")

	# create database
	mysql -h 134.129.90.220 -u root -p`cat /etc/mysql/melt.secret` <<< "CREATE DATABASE acm_$4;"
	mysql -h 134.129.90.220 -u root -p`cat /etc/mysql/melt.secret` <<< "GRANT ALL ON acm_$4.* TO '$4'@'localhost' IDENTIFIED BY '$password';"

	# create symlinks
	su - webmin -c "ssh hosted.ndacm.org ln -s /home/$4/public_html /var/www/hosted/$4"

	# Send Email
	EmailString="From: \"NDSU ACM\" <$adminEmail>\n"
	EmailString=$EmailString"To: \"$1 $2\" <$3>\n"
	EmailString=$EmailString"Subject: Welcome to the ACM"!"\n\n"
	EmailString=$EmailString"Hello $1 $2,\n\nWelcome to the NDSU Chapter of the Association for Computing Machinery"!" This automatically generated email is to inform you that your new ACM web account has been created.\n"
	EmailString=$EmailString"\tUsername: $4\n\tPassword: $password\n\n"
	EmailString=$EmailString"You can log in using your favorite ssh, ftp, or scp client to these servers:\n"
	EmailString=$EmailString"\thosted.ndacm.org\n\tmelt.acm.ndsu.nodak.edu\n\nIn addition, the following linux workstations are available to use in the ACM lounge:\n"
	EmailString=$EmailString"\tlab01.ndacm.org \n\tlab02.ndacm.org (coming soon!)\n\n"
	EmailString=$EmailString"Content in your public_html directory is served at the following addresses:\n"
	EmailString=$EmailString"\thttp://ndacm.org/~$4/\n\thttp://hosted.ndacm.org/$4\n\n"
	EmailString=$EmailString"You also have a MySQL database named acm_$4. The username and password to this database are the same as above. You can access this database at http://hosted.ndacm.org/phpmyadmin.\n"
	EmailString=$EmailString"Note: Your MySQL password is not associated with your password to log in to any of the machines listed above. To change your MySQL password, you may do so through the phpMyAdmin interface.\n\n"
	EmailString=$EmailString"If you need any assistance, want a fun and friendly atmosphere to work on projects or just want to hang out, the ACM invites you to stop by the lounge any time (located in IACC 162). "
	EmailString=$EmailString"To see what activities the ACM has coming up, you can check out the events calendar on the website.\n\n"
	EmailString=$EmailString"Regards,\n\n$adminSignature"
	(echo -e "$EmailString" | sendmail -i -t && echo "Email sent to $3.") || echo "Problem sending email!"
	add_members --admin-notify=y -r - members <<< $3
}

manEntry() {
	read -p "Enter first name > " first
	read -p "Enter last name > " last
	read -p "Enter uid > " uid
	read -p "Enter email > " email
	createUser $first $last $email $uid
}

# $1 - uid
# $2 - days to add
renewAccount() {
	today=$(date +%Y-%m-%d)
	ldapmodifyuser $1 accountExpires `date -d "$today ${2:-365} days"`
}

# $1 - uid
# $2 - attribute
# $3 - value
_ldapmodify() {
	. /etc/ldapscripts/ldapscripts.conf
	modifyString="dn: uid=$1,$USUFFIX,$SUFFIX\nreplace: $2\n$2: $3"
	echo -e "$modifyString" | ldapmodify -y $BINDPWDFILE -D $BINDDN -xh $SERVER || echo "Error updating $1\'s $2"
}

# Generate a random password
#  $1 = number of characters; defaults to 32
#  $2 = include special characters; 1 = yes, 0 = no; defaults to 1
function randpass() {
  [ "$2" == "0" ] && CHAR="[:alnum:]" || CHAR="[:graph:]"
    cat /dev/urandom | tr -cd "$CHAR" | head -c ${1:-32}
    echo
}

function webAccount() {
	clear
	echo "<<<Web Account Creation>>>"
	echo -n "Enter the org's name : "
	read orgName
	# implement cool things here
}

main

