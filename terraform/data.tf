data "terraform_remote_state" "noob-systems" {
  backend = "remote"
  config = {
    organization = "NoobSystems"
    workspaces = {
      name = "the-forgotten-link"
    }
  }
}
