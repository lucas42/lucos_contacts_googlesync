# lucos Contacts Google Sync
Syncs Google Contacts with lucos_contacts

## Running
`AUTHKEY=<apikey> CONTACTSKEY=<apikey> SYNCGROUP=<uri> docker-compose up -d`
The environment variables used are:
* **AUTHURL** (required) The base URL for lucos_auth (protocol & host)
* **AUTHKEY** (required) An API key for lucos_auth
* **CONTACTSURL** (required) The base URL for lucos_contacts (protocol & host)
* **CONTACTSKEY** (required) An API key for lucos_contacts
* **SYNCGROUP** (required) The URI for a group from Google's Contacts API (normally starts with "https://www.google.com/m8/feeds/groups/")

## Building
The build is configured to run in Dockerhub when a commit is pushed to the master branch in github.

## Supersceded
This project has been supersceded by [lucos_contacts_googlesync_import](https://github.com/lucas42/lucos_contacts_googlesync_import) which runs periodically on a cron, rather than needing to be refreshed.