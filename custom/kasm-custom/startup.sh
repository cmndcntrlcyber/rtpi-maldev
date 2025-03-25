#!/bin/bash
# Custom startup script for DevOps Kasm Workspace

# Create workspace directory if it doesn't exist
mkdir -p $HOME/workspace/repos
mkdir -p $HOME/workspace/projects

# Create desktop shortcuts
mkdir -p $HOME/Desktop

# VS Code shortcut
cat > $HOME/Desktop/code-server.desktop << EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=Visual Studio Code
Comment=Code Editing. Redefined.
Exec=code-server
Icon=vscode
Terminal=false
StartupNotify=true
Categories=Development;IDE;
EOL
chmod +x $HOME/Desktop/code-server.desktop

# Terminal shortcut
cat > $HOME/Desktop/terminal.desktop << EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=Terminal
Comment=Terminal Emulator
Exec=xfce4-terminal
Icon=utilities-terminal
Terminal=false
StartupNotify=true
Categories=System;TerminalEmulator;
EOL
chmod +x $HOME/Desktop/terminal.desktop

# Create a welcome message
cat > $HOME/welcome.txt << EOL
Welcome to the DevOps Environment!

This workspace includes:
- Git and Git LFS
- Docker CLI and Docker Compose
- VS Code Server
- Python development tools
- Node.js development tools
- Various command-line utilities

Your workspace is located at:
$HOME/workspace/

Enjoy your development!
EOL

# Create a startup notification
cat > $HOME/.config/autostart/welcome.desktop << EOL
[Desktop Entry]
Type=Application
Name=Welcome
Exec=xfce4-terminal --hold -e "cat $HOME/welcome.txt"
Terminal=false
X-GNOME-Autostart-enabled=true
EOL

# Configure Git
git config --global init.defaultBranch main

# Set VS Code as default editor
git config --global core.editor "code-server --wait"

# Create initial configuration for VS Code
mkdir -p $HOME/.config/code-server
cat > $HOME/.config/code-server/config.yaml << EOL
bind-addr: 127.0.0.1:8080
auth: none
disable-telemetry: true
EOL

# Add useful aliases to .bashrc
cat >> $HOME/.bashrc << EOL

# DevOps aliases
alias gs='git status'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gco='git checkout'
alias gb='git branch'
alias dc='docker-compose'
alias dps='docker ps'
alias di='docker images'
alias k='kubectl'

# Directory aliases
alias ws='cd $HOME/workspace'
alias repos='cd $HOME/workspace/repos'
alias projects='cd $HOME/workspace/projects'

# Welcome message
echo "Welcome to the DevOps Environment!"
echo "Type 'ws' to navigate to your workspace."
EOL

# Create symlink for easier access
ln -sf $HOME/workspace $HOME/Desktop/workspace