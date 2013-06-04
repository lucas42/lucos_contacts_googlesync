# lucos Contacts Google Sync
Syncs Google Contacts with lucos_contacts

## Setup
Create a text file called "settings" in the root of the project.  This should be a list of key/value pairs (separated by spaces, each pair on a new line)
* **authkey** (required) An API key for lucos_auth
* **contactskey** (required) An API key for lucos_contacts
* **syncgroup** (required) The URI for a group from Google's Contacts API (normally starts with "https://www.google.com/m8/feeds/groups/")

## Running
The web server is designed to be run within lucos_services, but can be run standalone by running server.rb with ruby, passing in the port to run on as the first parameter and the domain of a running lucos_services instance as the second paramatere