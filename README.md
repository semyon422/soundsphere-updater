# soundsphere-updater
soundsphere update repository builder.  

`sudo apt install p7zip-full`  
`sudo gpasswd -a www-data username`  
```
server {
    server_name dl.soundsphere.xyz;

    location / {
        root /path/to/repo;
        autoindex on;
    }
}
```
