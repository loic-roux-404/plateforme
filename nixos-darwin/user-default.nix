{
  pkgs,
  currentSystemUser,
  ...
}:

# Opinionated default settings for an user
#
# Using antigravity-ide and zed as editors
# Fish as default shell
#

{

  homebrew = {
    enable = true;
    casks = [
      "google-chrome"
      "antigravity-ide"
      "zed"
    ];

    brews = [
      "gnupg"
    ];
  };

  users.users.${currentSystemUser} = {
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [ ];
  };

}
