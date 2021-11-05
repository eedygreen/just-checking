locals {
  zones = {
    0 : "a"
    1 : "b"
    2 : "c"
  }
  suffix = {
    tools = "tools.bitsoops.com"
    prod  = "bitsoclusterprod.bitsoops.com"
  }

  vpc_prefix = {
    tools = ""
    prod  = "vpc."
  }

  subnet_prefix = {
    tools = "tools-private-"
    prod  = ""
  }
}
