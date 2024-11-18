#!/bin/bash
echo "Adding update-arch to /usr/local/bin"
echo "Use update-arch to update system."
sudo cp ./update.sh /usr/local/bin/update-arch
sudo chmod +x /usr/local/bin/update-arch
