# My Omarchy 3.3 dotfiles

This repo contains every thing I have tuned so far on a fresh Omarchy 3.3 install.

How to use it : 
- install Omarchy
- place your ssh keys in ~/.ssh
- clone this repo
- ~/dotfiles/bootstrap.sh --dry-run
- check the output
- then same thing without dry run

Everything should be in place.

I have tried to change as few things as possible, because Omarchy does a lot of work under the hood for theming etc.

Because Omarchy may stop shipping some things in the future, my policy is : if I stow anything that needs a package installed, I install it as part of the script (/script/install-packages.sh), even if Omarchy already has it installed today.

The main difference, is I browse the filesystem with Yazi, not Nautilus, so I auto-mount external drives in a ~/drives symlink for easy access and make previews work very well in Yazi.

I also setup Catpuccin for a few other tools (fzf, etc) and added a few aliases and functions (copy and paste form wl-copy for example...).

I'm a beginner in ricing, and this is my first Arch/Hyprland config, so I'm always eager to learn, feel free to reach out and use anything you like. Let's just be nice, thx :)
