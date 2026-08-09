# Theme
set -g theme_nerd_fonts yes

# vscode 
if test "$TERM_PROGRAM" = vscode
  and type -q code
  . (code --locate-shell-integration-path fish | psub)
end

# create functions
function coam
	git add .;
	git commit -m $argv
end
function cloam
	git add .;
	git commit -m $argv;
	git push
end

function pte
	tree -L $argv -u -g -p -d
end

ulimit -n 6553

function del-branch
	git push -d origin $argv && git branch -d $argv
end

set -g fish_user_paths "/usr/local/sbin" $fish_user_paths
set -g fish_user_paths "/bin" $fish_user_paths

function envsource
  for line in (cat $argv | grep -v '^#')
    set item (string split -m 1 '=' $line)
    set -gx $item[1] $item[2]
    echo "Exported key $item[1]"
  end
end

. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
