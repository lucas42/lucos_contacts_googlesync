# lucos Contacts Google Sync
Syncs Google Contacts with lucos_contacts

## Running
`AUTHKEY=<apikey> CONTACTSKEY=<apikey> SYNCGROUP=<uri> docker-compose up -d`
The environment variables used are:
* **AUTHKEY** (required) An API key for lucos_auth
* **CONTACTSKEY** (required) An API key for lucos_contacts
* **SYNCGROUP** (required) The URI for a group from Google's Contacts API (normally starts with "https://www.google.com/m8/feeds/groups/")

## Building
The build is configured to run in Dockerhub when a commit is pushed to the master branch in github.