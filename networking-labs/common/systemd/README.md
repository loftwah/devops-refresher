Systemd Examples for Lab VMs

These examples help persist nftables rules and ensure FRR starts cleanly on Debian/Ubuntu GNS3 nodes.

Persist nftables rules

- Copy `nftables.conf.example` to `/etc/nftables.conf` and enable the unit:

```bash
sudo cp networking-labs/common/systemd/nftables.conf.example /etc/nftables.conf
sudo systemctl enable --now nftables.service 2>/dev/null || \
  (sudo cp networking-labs/common/systemd/nft-restore.service /etc/systemd/system/ && \
   sudo systemctl daemon-reload && \
   sudo systemctl enable --now nft-restore.service)
```

Start FRR at boot

```bash
sudo apt-get install -y frr frr-pythontools
sudo systemctl enable --now frr
```

Notes

- Many distros ship `nftables.service`. If not present, the fallback `nft-restore.service` provided here loads `/etc/nftables.conf` at boot.
- Keep `/etc/frr/frr.conf` owned by `frr:frr` and validate with `vtysh -c 'show running-config'`.
