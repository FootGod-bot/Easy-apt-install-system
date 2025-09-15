# How to set up the Easy Apt Replacer
# Step 1:
First, make a fork of this github.
Next, you need to edit system.json with your file name, the raw url to your file, and the folder to save it to.
You can also set the perms of files with the permissions section.
# Step 2:
Fill in all python and apt requirments. The apt requirments are done first. 
Next, open the install, uninstall, and update file and find the variable JSON_URL. Replace that with the raw link to system.json
# Step 3:
After everything is setup, run 
```bash <(curl -sL https://raw.githubusercontent.com/FootGod-bot/Universal-ssh-keys/refs/heads/main/install.sh)```
but replace it with your link to the install.sh. Update is
```bash <(curl -sL https://raw.githubusercontent.com/FootGod-bot/Universal-ssh-keys/refs/heads/main/update.sh)```
and uninstall is
```bash <(curl -sL https://raw.githubusercontent.com/FootGod-bot/Universal-ssh-keys/refs/heads/main/uninstall.sh)```
.
# Enjoy
