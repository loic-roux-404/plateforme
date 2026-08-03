{
  pkgs,
  currentSystemUser,
  ...
}:

# Opinionated default settings for an user
#
# Using visual-studio-code and zed as editors
# Fish as default shell
#

{

  homebrew = {
    enable = true;
    casks = [
      "google-chrome"
      "visual-studio-code"
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
