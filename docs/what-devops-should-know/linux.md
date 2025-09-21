# What a Senior DevOps Engineer Should Know About Linux

## Why Linux matters to DevOps

- Ubuntu and Alpine are the two most common bases you will meet day to day on EC2 instances and inside containers. Ubuntu fits full-fat servers with systemd, snaps, and a large ecosystem. Alpine fits tiny containers that start fast and ship fewer CVEs by design.
- You need to read logs, manage services, patch systems, debug networking, secure SSH, build small images, and automate bootstrap at launch time. That is the job.

---

## Mental model: Ubuntu vs Alpine

- Init and services
  - Ubuntu uses **systemd** and `systemctl`. Logs live in **journald**, queried with `journalctl`. ([manpages.ubuntu.com][1])
  - Alpine uses **OpenRC**. Logs default to BusyBox **syslogd** with `logread`, or another syslog if you install one. ([wiki.alpinelinux.org][2])

- C library and compatibility
  - Ubuntu uses **glibc**.
  - Alpine uses **musl**. Some prebuilt binaries targeting glibc will not run without compatibility layers. Prefer compiling against musl or pick a glibc-based image if you need glibc. ([wiki.alpinelinux.org][3], [wiki.musl-libc.org][4])

- Package managers
  - Ubuntu uses **APT**. Learn `apt update`, `apt install`, and `--no-install-recommends` for lean images. ([Ubuntu][5])
  - Alpine uses **apk**. Use `apk add --no-cache` for lean layers. ([GitHub][6])

---

## Working with packages

### Ubuntu quick wins

```bash
# Update metadata then install only hard deps
sudo apt update
sudo apt install --no-install-recommends -y curl jq

# Prove success with exit codes
echo $?
# 0 means success. Non-zero means failure.
```

- `--no-install-recommends` keeps images and AMIs smaller by skipping recommended packages. Canonical report large reductions in Docker image size using this flag. ([Ubuntu][5])

### Alpine quick wins

```bash
# Install with no cache to avoid stale indexes and large layers
sudo apk add --no-cache curl jq
echo $?
```

- `--no-cache` avoids storing the index locally and is the recommended pattern in Docker images. ([GitHub][6])

---

## Users, groups, and sudo

### Ubuntu

```bash
# Create an unprivileged user and grant sudo safely
sudo adduser deploy
sudo usermod -aG sudo deploy

# Test
sudo -l -U deploy
```

- On Ubuntu, `adduser` is a friendly wrapper around lower level `useradd`. ([Ask Ubuntu][7])

### Alpine

```bash
# BusyBox adduser is different to Debian/Ubuntu
# Create user, group, home, and shell explicitly
sudo addgroup -S app && sudo adduser -S -G app -h /home/app -s /bin/ash app

# Test
id app
```

- Alpine ships BusyBox tools by default. Its `adduser` options differ from Debian/Ubuntu. ([wiki.alpinelinux.org][8])

---

## Services and background processes

### Ubuntu with systemd

Create a service that runs a local binary and restarts on failure.

```bash
# /etc/systemd/system/sample.service
[Unit]
Description=Sample HTTP server
After=network-online.target

[Service]
ExecStart=/usr/local/bin/sample -p 8080
Restart=on-failure
RestartSec=3
User=app
Group=app

[Install]
WantedBy=multi-user.target
```

Run it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now sample
sudo systemctl status sample
journalctl -u sample -n 50 --no-pager
```

- Service and timer units are defined by systemd. Use `systemctl` to manage and `journalctl` to read logs. ([manpages.ubuntu.com][1])

#### Replacing cron with a systemd timer

```bash
# /etc/systemd/system/log-trim.service
[Unit]
Description=Trim application logs

[Service]
Type=oneshot
ExecStart=/usr/local/bin/trim-logs.sh

# /etc/systemd/system/log-trim.timer
[Unit]
Description=Run log trim every 5 minutes

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target

# Activate
sudo systemctl daemon-reload
sudo systemctl enable --now log-trim.timer
systemctl list-timers | grep log-trim
```

- Timers schedule services on systemd systems. ([manpages.ubuntu.com][9])

### Alpine with OpenRC

Create and manage an OpenRC service:

```bash
# /etc/init.d/sample
#!/sbin/openrc-run
name="sample"
command="/usr/local/bin/sample"
command_args="-p 8080"
command_user="app:app"
pidfile="/run/${RC_SVCNAME}.pid"

depend() {
  need net
}

# Enable and start
sudo chmod +x /etc/init.d/sample
sudo rc-update add sample default
sudo rc-service sample start
sudo rc-service sample status
```

- Alpine uses OpenRC for init and service supervision. ([wiki.alpinelinux.org][2])

---

## Logging

### Ubuntu

```bash
# View last 100 lines of a unit’s logs
journalctl -u sample -n 100 -o short-iso

# Follow logs
journalctl -u sample -f
```

- `journalctl` queries systemd’s journal. Use fields and filters for deep triage. ([manpages.ubuntu.com][10])

Log rotation for classic files:

```bash
sudo nano /etc/logrotate.d/sample
/var/log/sample/*.log {
  daily
  rotate 7
  compress
  missingok
  notifempty
  copytruncate
}
sudo logrotate -d /etc/logrotate.conf  # dry run
```

- `logrotate` handles file log rotation if you are not fully on journald. ([man7.org][11])

### Alpine

```bash
# BusyBox syslogd + logread
rc-update add syslog boot
rc-service syslog restart

# Read logs
logread | tail -n 100
```

- Alpine uses BusyBox syslog by default, though rsyslog or others are available if you prefer. ([wiki.alpinelinux.org][12])

---

## Networking and firewalls

### Inspect and test

```bash
# IP addresses and routes
ip addr
ip route

# Sockets
ss -tulpen | head
```

- `ip` and `ss` are the modern tools for interfaces, routing, and sockets. ([man7.org][13])

### Ubuntu firewall with UFW

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

sudo ufw status verbose
```

- UFW provides a simple interface to netfilter. ([Ubuntu Help][14])

### nftables if you need fine control

```bash
# Minimal nftables ruleset example
sudo nft add table inet filter
sudo nft add chain inet filter input { type filter hook input priority 0\; }
sudo nft add rule inet filter input ct state established,related accept
sudo nft add rule inet filter input iif lo accept
sudo nft add rule inet filter input tcp dport {22,80,443} accept
sudo nft add rule inet filter input counter drop

sudo nft list ruleset
```

- nftables is the modern packet filter. Use it when UFW is too limited. ([wiki.nftables.org][15])

### Static IPs on Ubuntu

```bash
# /etc/netplan/01-static.yaml
network:
  version: 2
  ethernets:
    ens5:
      dhcp4: false
      addresses: [10.0.1.10/24]
      routes:
        - to: default
          via: 10.0.1.1
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]

sudo netplan apply
```

- Netplan manages network config on modern Ubuntu. ([Netplan][16])

---

## Storage and filesystems

```bash
# Discover disks and filesystems
lsblk -f
# Mount a new filesystem (example)
sudo mkfs.ext4 /dev/nvme1n1
sudo mkdir -p /data
sudo mount -o noatime /dev/nvme1n1 /data

# Persist across reboots
echo '/dev/nvme1n1 /data ext4 defaults,noatime 0 2' | sudo tee -a /etc/fstab

# Check free space
df -h
# Find big directories
sudo du -xh /var | sort -h | tail
```

- `lsblk`, `mount`, `fstab`, and `swapon` are the core tools here. The `noatime` and `nosuid/nodev/noexec` options can reduce IO and risk. ([man7.org][17], [linux.die.net][18])

### Swap tuning

```bash
# See swappiness
cat /proc/sys/vm/swappiness
# Temporary change until reboot
sudo sysctl vm.swappiness=10
# Persist
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
```

- VM tuning parameters are documented under `/proc/sys/vm`. Lower swappiness prefers RAM, higher prefers swapping. Choose based on workload risk. ([docs.kernel.org][19])

---

## Jobs and scheduling

### Ubuntu: cron or systemd timers

```bash
# Per-user cron
crontab -e
# Example: run every 15 minutes
*/15 * * * * /usr/local/bin/metrics-shipper

# systemd timers are often better integrated for services and logging
systemctl list-timers
```

- Timers integrate with journald and dependencies, which is handy for production automation. ([manpages.ubuntu.com][9])

### Alpine: BusyBox cron

```bash
# Ensure crond is running and enabled at boot
sudo rc-update add crond default
sudo rc-service crond start

# User crontab
crontab -e
```

- Alpine ships BusyBox cron by default. Other cron packages are available if you prefer. ([wiki.alpinelinux.org][20])

---

## SSH setup and hardening

```bash
# Create a key on your workstation if you do not have one
ssh-keygen -t ed25519 -C "dean@laptop"

# Copy to server
ssh-copy-id -i ~/.ssh/id_ed25519.pub ubuntu@ec2-x-x-x-x.ap-southeast-2.compute.amazonaws.com

# Harden server side
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo nano /etc/ssh/sshd_config
# Typical changes:
#   PasswordAuthentication no
#   PermitRootLogin no
#   PubkeyAuthentication yes
#   AllowUsers ubuntu deploy
sudo systemctl reload sshd
```

- Use modern ciphers and disable password login where possible. Mozilla’s OpenSSH guidance is a sensible reference. ([infosec.mozilla.org][21])

---

## Observability and triage checklist

### Ubuntu

```bash
# Services, CPU, memory, IO, sockets, logs
systemctl --failed
top            # or htop if installed
vmstat 1 5
iostat -xz 1 3        # if sysstat is installed
ss -s
journalctl -p err -b
```

### Alpine

```bash
# Similar approach, without systemd tools
top
vmstat 1 5
iostat -xz 1 3        # sysstat package
ss -s
logread | tail
```

---

## Containers and images

### When to choose Ubuntu vs Alpine base images

- Ubuntu base is helpful when you need glibc or systemd-style behaviour in containers used as build stages.
- Alpine base is helpful for tiny runtime images. Make sure the app is compiled against musl or does not depend on glibc specific behaviour. ([wiki.alpinelinux.org][3])

### Multi-stage Docker examples

Ubuntu build stage, Alpine runtime, for a Go API:

```dockerfile
# Build stage with Ubuntu
FROM ubuntu:24.04 AS build
RUN apt update && apt install --no-install-recommends -y ca-certificates curl git build-essential \
 && rm -rf /var/lib/apt/lists/*
ENV CGO_ENABLED=0
RUN curl -fsSL https://go.dev/dl/go1.22.5.linux-amd64.tar.gz -o /tmp/go.tgz \
 && tar -C /usr/local -xzf /tmp/go.tgz
ENV PATH=/usr/local/go/bin:$PATH
WORKDIR /src
COPY . .
RUN go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/app

# Minimal Alpine runtime
FROM alpine:3.20
RUN addgroup -S app && adduser -S -G app -h /home/app app
USER app
COPY --from=build /out/app /usr/local/bin/app
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/app"]
```

- `--no-install-recommends` reduces layer size on Ubuntu.
- `apk add --no-cache` is the Alpine pattern if you need packages at runtime. ([Ubuntu][5], [GitHub][6])

---

## AWS workflows that matter

### Picking images

- Ubuntu: Canonical publishes official AMIs for each region. Search by owner and version. ([Ubuntu Documentation][22])
- Alpine: Community AMIs exist, but for most teams Alpine is used inside containers on ECS or EKS rather than as an EC2 OS.

### Bootstrapping servers with cloud-init user-data

```yaml
#cloud-config
package_update: true
packages:
  - nginx
  - fail2ban
users:
  - default
  - name: deploy
    groups: [sudo]
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
write_files:
  - path: /etc/nginx/conf.d/app.conf
    content: |
      server {
        listen 80;
        location / {
          proxy_pass http://127.0.0.1:8080;
        }
      }
runcmd:
  - systemctl enable --now nginx
  - ufw allow 22/tcp
  - ufw allow 80/tcp
  - ufw --force enable
```

- cloud-init is the standard way to configure new cloud images, including Ubuntu on EC2. ([Ubuntu Documentation][23], [cloudinit.readthedocs.io][24])

---

## Real world end-to-end example

### Goal

Run a small HTTP API on an Ubuntu EC2 instance, reverse proxy via Nginx, systemd for supervision, UFW permittive for 22 and 80. The app binary is built into a tiny Alpine container for ECS as well.

### Steps

1. Build your app image locally

```bash
export IMAGE_TAG=$(git rev-parse --short HEAD)
docker build -t "myapi:${IMAGE_TAG}" .
docker run -it --rm -p 8080:8080 "myapi:${IMAGE_TAG}"
curl -fsS http://localhost:8080/health && echo "OK" || echo "FAIL"
echo $?
```

The image tag comes from the current Git commit (see [ADR-008](../decisions/ADR-008-container-image-tagging.md)), so repeating the lab rebuilds the same artifact.

- Exit code `0` means the health check succeeded and the container is serving traffic.

2. Provision EC2 with Ubuntu and cloud-init

- Launch an **Ubuntu 24.04** AMI in `ap-southeast-2`. Attach a security group that allows 22 and 80. Use the cloud-init above. Canonical’s docs show how to find the correct AMI per region. ([Ubuntu Documentation][22])

3. Copy the binary to the instance and create a service

```bash
scp ./bin/linux-amd64/app ubuntu@ec2-X-X-X-X.ap-southeast-2.compute.amazonaws.com:/usr/local/bin/app
ssh ubuntu@ec2-... "sudo chown root:root /usr/local/bin/app && sudo chmod 0755 /usr/local/bin/app"
```

Create the service and start it:

```bash
ssh ubuntu@ec2-... 'sudo tee /etc/systemd/system/app.service >/dev/null <<EOF
[Unit]
Description=My API
After=network-online.target
[Service]
ExecStart=/usr/local/bin/app -p 8080
Restart=on-failure
User=www-data
Group=www-data
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload && sudo systemctl enable --now app && sudo systemctl status --no-pager app'
```

4. Wire up Nginx

```bash
ssh ubuntu@ec2-... 'sudo tee /etc/nginx/sites-available/app >/dev/null <<EOF
server {
  listen 80;
  location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
}
EOF
sudo ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app
sudo nginx -t && sudo systemctl reload nginx'
```

5. Open the firewall

```bash
ssh ubuntu@ec2-... 'sudo ufw allow 22/tcp && sudo ufw allow 80/tcp && sudo ufw --force enable && sudo ufw status verbose'
```

- UFW is the simple front door on Ubuntu. ([Ubuntu Help][14])

6. Validate end to end

```bash
curl -fsS http://YOUR.EC2.IP/health && echo "OK" || (echo "FAIL"; exit 1)
ssh ubuntu@ec2-... 'journalctl -u app -n 50 --no-pager'
```

If you also deploy to ECS, push the Alpine image to ECR and run behind an ALB. The same container works there because it is statically compiled or linked against musl.

---

## Security checklist that pays off

- SSH keys only. Disable password login. Limit `AllowUsers`. Use a bastion or SSM if possible. Refer to hardened `sshd_config` examples. ([infosec.mozilla.org][21])
- Least privilege users and groups. Services should not run as root.
- Keep images and AMIs lean so there are fewer CVEs to patch. `--no-install-recommends` on Ubuntu, `--no-cache` on Alpine. ([Ubuntu][5], [GitHub][6])
- Enable automatic security updates on Ubuntu with unattended-upgrades where appropriate, with controlled reboots. ([Ubuntu Documentation][25])
- Prefer nftables or UFW on hosts, and security groups or NACLs in VPCs.
- Keep logs. On Ubuntu use journald and `journalctl` filters. On Alpine ensure a syslog is running. ([manpages.ubuntu.com][10], [wiki.alpinelinux.org][12])

---

## Common pitfalls and how to avoid them

- Dropping into Alpine then discovering a glibc only binary will not run. Solution: rebuild against musl or use a glibc base. ([wiki.alpinelinux.org][3])
- Installing heaps of Ubuntu recommended packages by default in Docker images. Solution: add `--no-install-recommends` and remove apt lists in the same layer. ([Ubuntu][5])
- Expecting `systemctl` in an Alpine container. You will not find it. Use OpenRC or a one-process container pattern. ([wiki.alpinelinux.org][2])
- Enabling cron jobs in Alpine but forgetting to start `crond` or add it to default runlevel. ([wiki.alpinelinux.org][20])

---

## Practice exercises

Short, high-signal tasks you can actually run.

### Service and logs on Ubuntu

1. Write a tiny shell script service:

```bash
sudo tee /usr/local/bin/heartbeat.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "heartbeat $(date -Iseconds)" | systemd-cat -t heartbeat -p info
EOF
sudo chmod +x /usr/local/bin/heartbeat.sh
```

2. Create timer and service:

```bash
sudo tee /etc/systemd/system/heartbeat.service >/dev/null <<'EOF'
[Unit]
Description=Heartbeat
[Service]
Type=oneshot
ExecStart=/usr/local/bin/heartbeat.sh
EOF

sudo tee /etc/systemd/system/heartbeat.timer >/dev/null <<'EOF'
[Unit]
Description=Run heartbeat every minute
[Timer]
OnCalendar=*:*:00
Persistent=true
[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now heartbeat.timer
systemctl list-timers | grep heartbeat
journalctl -t heartbeat -f
```

What to learn: systemd unit structure, timers, journald filtering. ([manpages.ubuntu.com][9])

### OpenRC service on Alpine

Create a simple OpenRC script that tails a file and writes lines to syslog:

```bash
sudo tee /usr/local/bin/tail-writer.sh >/dev/null <<'EOF'
#!/bin/sh
while true; do
  echo "tick $(date -Iseconds)"
  sleep 5
done
EOF
sudo chmod +x /usr/local/bin/tail-writer.sh

sudo tee /etc/init.d/tailwriter >/dev/null <<'EOF'
#!/sbin/openrc-run
name="tailwriter"
command="/usr/local/bin/tail-writer.sh"
command_background=true
depend() { need net; }
EOF
sudo chmod +x /etc/init.d/tailwriter
sudo rc-update add tailwriter default
sudo rc-service tailwriter start
logread | tail
```

What to learn: OpenRC run scripts, runlevels, BusyBox logging. ([wiki.alpinelinux.org][2])

### Firewall and sockets

```bash
# Ubuntu
sudo ufw reset
sudo ufw default deny incoming
sudo ufw allow 22/tcp
sudo ufw allow 8080/tcp
sudo ufw --force enable
ss -tulpen | grep 8080 || echo "no listener on 8080 yet"
```

Add a simple listener:

```bash
# Start a netcat listener and test from another terminal
nc -l -p 8080 &
echo "hello" | nc 127.0.0.1 8080
```

Check UFW logs and rules:

```bash
sudo ufw status verbose
journalctl -u ufw -n 50 --no-pager
```

What to learn: linking sockets to firewall rules and validating traffic. ([Ubuntu Help][14], [man7.org][26])

### Netplan static IP in a sandbox

Write a netplan config for a VM test interface and apply, then revert. Practice reading `ip addr` and `ip route`. ([Netplan][16])

---

## Minimal directory structure for a small Linux-backed service

```
infra/
  cloud-init/
    ubuntu-web.yaml
  packer/                # optional: custom AMIs
  scripts/
    trim-logs.sh
    rotate-keys.sh
system/
  ubuntu/
    systemd/app.service
    systemd/app.timer
    ufw/allow-app.sh
  alpine/
    openrc/app
    openrc/install.sh
docker/
  Dockerfile
  docker-compose.yaml    # if you use it for local dev
docs/
  runbook.md             # how to start, stop, patch, roll back
```

- Everything is text and reviewable in Git. That keeps ops changes visible and repeatable.

---

## References

- Ubuntu systemd service and journald manpages. ([manpages.ubuntu.com][1])
- UFW official documentation. ([Ubuntu Help][14])
- Systemd timer units. ([manpages.ubuntu.com][9])
- Alpine OpenRC and system logging wiki pages. ([wiki.alpinelinux.org][2])
- Alpine apk and `--no-cache`. ([docs.alpinelinux.org][27], [GitHub][6])
- musl on Alpine and differences from glibc. ([wiki.alpinelinux.org][3], [wiki.musl-libc.org][4])
- Canonical guidance on `--no-install-recommends`. ([Ubuntu][5])
- Netplan documentation for static IPs. ([Netplan][16])
- AWS and Ubuntu AMIs. ([Ubuntu Documentation][22])
- nftables wiki. ([wiki.nftables.org][15])
- logrotate manpage. ([man7.org][11])
- ip and ss manpages. ([man7.org][13])
- OpenSSH hardening recommendations. ([infosec.mozilla.org][21])
- cloud-init examples and intro docs. ([cloudinit.readthedocs.io][24], [Ubuntu Documentation][23])

---

[1]: https://manpages.ubuntu.com/manpages/questing/en/man5/systemd.service.5.html "Ubuntu Manpage: systemd.service - Service unit configuration"
[2]: https://wiki.alpinelinux.org/wiki/OpenRC "OpenRC - Alpine Linux"
[3]: https://wiki.alpinelinux.org/wiki/Musl "Musl - Alpine Linux"
[4]: https://wiki.musl-libc.org/getting-started.html "musl libc - Getting started"
[5]: https://ubuntu.com/blog/we-reduced-our-docker-images-by-60-with-no-install-recommends "We reduced our Docker images by 60% with –no-install-recommends - Ubuntu"
[6]: https://github.com/alpinelinux/docker-alpine/blob/master/docs/usage.adoc "docker-alpine/docs/usage.adoc at master - GitHub"
[7]: https://askubuntu.com/questions/345974/what-is-the-difference-between-adduser-and-useradd "What is the difference between adduser and useradd? - Ask Ubuntu"
[8]: https://wiki.alpinelinux.org/wiki/BusyBox "BusyBox - Alpine Linux"
[9]: https://manpages.ubuntu.com/manpages/trusty/en/man5/systemd.timer.5.html "Ubuntu Manpage: systemd.timer - Timer unit configuration"
[10]: https://manpages.ubuntu.com/manpages/noble/en/man1/journalctl.1.html "Ubuntu Manpage: journalctl - Print log entries from the systemd journal"
[11]: https://www.man7.org/linux/man-pages/man8/logrotate.8.html "logrotate (8) - Linux manual page - man7.org"
[12]: https://wiki.alpinelinux.org/wiki/Syslog "Syslog - Alpine Linux"
[13]: https://www.man7.org/linux/man-pages/man8/ip.8.html "ip (8) - Linux manual page - man7.org"
[14]: https://help.ubuntu.com/community/UFW "UFW - Community Help Wiki - Official Ubuntu Documentation"
[15]: https://wiki.nftables.org/wiki-nftables/index.php/Main_Page "nftables wiki"
[16]: https://netplan.readthedocs.io/en/latest/using-static-ip-addresses/ "How to use static IP addresses - Netplan documentation"
[17]: https://www.man7.org/linux/man-pages/man8/lsblk.8.html "lsblk (8) - Linux manual page - man7.org"
[18]: https://linux.die.net/man/8/mount "mount (8): mount filesystem - Linux man page"
[19]: https://docs.kernel.org/admin-guide/sysctl/vm.html "Documentation for /proc/sys/vm/ — The Linux Kernel documentation"
[20]: https://wiki.alpinelinux.org/wiki/Cron "Cron - Alpine Linux"
[21]: https://infosec.mozilla.org/guidelines/openssh "OpenSSH - Mozilla"
[22]: https://documentation.ubuntu.com/aws/aws-how-to/instances/find-ubuntu-images/ "Find Ubuntu images on AWS - Ubuntu on AWS documentation"
[23]: https://documentation.ubuntu.com/server/explanation/intro-to/cloud-init/ "Introduction to cloud-init - Ubuntu Server documentation"
[24]: https://cloudinit.readthedocs.io/en/latest/topics/examples.html "All cloud config examples - cloud-init 25.2 documentation"
[25]: https://documentation.ubuntu.com/server/how-to/software/automatic-updates/ "Automatic updates - Ubuntu Server documentation"
[26]: https://www.man7.org/linux/man-pages/man8/ss.8.html "ss (8) - Linux manual page - man7.org"
[27]: https://docs.alpinelinux.org/user-handbook/0.1a/Working/apk.html "Working with the Alpine Package Keeper (apk) - Alpine Linux Documentation"
