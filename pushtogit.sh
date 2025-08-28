#!/bin/bash

DEST="$HOME/MyBackup"
REPO_URL_FILE="$DEST/.repo_url"

# Colors
GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
RESET="\e[0m"

# === Step 1: Ensure SSH key exists ===
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo -e "${YELLOW}No SSH key found. Creating a new one...${RESET}"
    read -p "Enter your GitHub email: " email
    ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/id_ed25519" -N ""
    echo -e "${GREEN}SSH key generated at ~/.ssh/id_ed25519${RESET}"
fi

# Start ssh-agent and add key
eval "$(ssh-agent -s)" >/dev/null
ssh-add ~/.ssh/id_ed25519 >/dev/null

# Test connection
if ! ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo -e "${CYAN}Please add this SSH key to your GitHub account:${RESET}"
    echo
    cat "$HOME/.ssh/id_ed25519.pub"
    echo
    echo -e "${YELLOW}Go to https://github.com/settings/keys → New SSH key → paste it → Save${RESET}"
    read -p "Press Enter after adding the key to GitHub..."
fi

# === Step 2: Check MyBackup folder ===
if [ ! -d "$DEST" ]; then
    echo -e "${RED}Error: $DEST does not exist. Run your backup script first.${RESET}"
    exit 1
fi

cd "$DEST" || exit

# === Step 3: Git repo setup ===
if [ ! -d ".git" ]; then
    echo -e "${CYAN}Git is not initialized for MyBackup. Setting it up now...${RESET}"
    git init
    git branch -M main

    echo -e "${CYAN}Enter your GitHub repo name (without user, e.g. MyBackupConfigs):${RESET}"
    read -r repo_name

    repo_url="git@github.com:$(git config --global user.name)/$repo_name.git"
    echo "$repo_url" > "$REPO_URL_FILE"
    git remote add origin "$repo_url"

    echo -e "${GREEN}Git setup complete. Repo linked to: $repo_url${RESET}"
else
    if [ ! -f "$REPO_URL_FILE" ]; then
        echo -e "${CYAN}No stored repo URL. Please enter your GitHub repo (name only, e.g. MyBackupConfigs):${RESET}"
        read -r repo_name
        repo_url="git@github.com:$(git config --global user.name)/$repo_name.git"
        git remote remove origin 2>/dev/null
        git remote add origin "$repo_url"
        echo "$repo_url" > "$REPO_URL_FILE"
    else
        repo_url=$(cat "$REPO_URL_FILE")
        # Force SSH if remote accidentally set to HTTPS
        if [[ "$repo_url" == https://* ]]; then
            echo -e "${YELLOW}HTTPS remote detected. Converting to SSH...${RESET}"
            repo_url="git@github.com:$(echo "$repo_url" | sed -E 's#https://github.com/([^/]+)/([^/]+)(\.git)?#\1/\2.git#')"
            git remote remove origin 2>/dev/null
            git remote add origin "$repo_url"
            echo "$repo_url" > "$REPO_URL_FILE"
        fi
    fi
fi

# === Step 4: Commit & Push ===
git add .
git commit -m "Backup update: $(date +"%H:%M %d-%m-%Y")" || echo -e "${CYAN}No changes to commit.${RESET}"
git push -u origin main

echo -e "${GREEN}Push to GitHub completed successfully via SSH!${RESET}"

