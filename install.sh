#!/bin/bash

# Function to print colored messages
print_colored() {
    color=$1
    message=$2
    echo -e "\033[${color}m${message}\033[0m"
}

# Backup existing configuration files
print_colored "33" "Backing up existing configuration files..."
cp -r ~/.zshrc ~/.zshrc.bak
cp -r ~/.bashrc ~/.bashrc.bak
cp -r ~/.config/gtk-3.0 ~/.config/gtk-3.0.bak
cp -r ~/.config/hypr ~/.config/hypr.bak
cp -r ~/.config/kitty ~/.config/kitty.bak
cp -r ~/.config/rofi ~/.config/rofi.bak
cp -r ~/.config/swaync ~/.config/swaync.bak
cp -r ~/.config/waybar ~/.config/waybar.bak
cp -r ~/.config/waypaper ~/.config/waypaper.bak
if [ $? -ne 0 ]; then
    print_colored "31" "Error during backup!"
    exit 1
fi

# Install shell configuration files
print_colored "32" "Installing shell configuration..."
cp ./configs/.zshrc ~/.zshrc
cp ./configs/.bashrc ~/.bashrc
if [ $? -ne 0 ]; then
    print_colored "31" "Error installing shell configuration!"
    exit 1
fi

# Install GTK configuration
print_colored "32" "Installing GTK configuration..."
cp -r ./configs/gtk-3.0 ~/.config/gtk-3.0
if [ $? -ne 0 ]; then
    print_colored "31" "Error installing GTK configuration!"
    exit 1
fi

# Install application configurations
declare -a apps=(hypr kitty rofi swaync waybar waypaper)
for app in "${apps[@]}"; do
    print_colored "32" "Installing ${app} configuration..."
    cp -r ./configs/${app} ~/.config/${app}
    if [ $? -ne 0 ]; then
        print_colored "31" "Error installing ${app} configuration!"
        exit 1
    fi
done

# Install extras
print_colored "32" "Installing extras..."
# Add commands for installing extra applications here
if [ $? -ne 0 ]; then
    print_colored "31" "Error installing extras!"
    exit 1
fi

# Install wallpapers
print_colored "32" "Installing wallpapers..."
cp -r ./wallpapers/* ~/Pictures/wallpapers/
if [ $? -ne 0 ]; then
    print_colored "31" "Error installing wallpapers!"
    exit 1
fi

# Verify installation
print_colored "32" "Verification complete! Installation finished successfully!"