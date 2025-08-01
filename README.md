# minideploy

Minideploy is simple tool to install software to remote machines.

# Usage

```bash
minideploy openvpn # install on local machine
minideploy openvpn root@10.0.0.1 password # install on remote machine
```

# External recipies

If you want to use your scripts with `minideploy`, you can publish github repository containing `minideploy.sh` file.

After you can install it like:

```bash
minideploy your_name/your_repo
```

Each recipe should contain metadata in format

```bash
#!/bin/bash

# minideploy meta
# name: OpenVPN
# description: OpenVPN server setup
# end
```

and return json in case of successfull or error installation

```json
{
    "status": "success/error",
    "info": "you can put creds here or smth"
}
```