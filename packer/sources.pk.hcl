// In your sources file, you can create a configuration for a builder that you
// want to reuse between multiple steps in the build. Just leave the source
// and destination images out of this source, and set them specifically in each
// step without having to set all of the other options over and over again.

source "docker" "example" {
  commit = true
  // any other configuration you want for your Docker containers
}
