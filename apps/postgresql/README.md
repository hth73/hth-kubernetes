# PostgreSQL Server und TrueNAS & iSCSI Storage für Kubernetes

<img src="https://img.shields.io/badge/TrueNAS-0095D5?style=flat&logo=truenas&labelColor=ffffff&logoColor=0095D5" /> <img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=flat&logo=postgresql&labelColor=ffffff&logoColor=4169E1" /> <img src="https://img.shields.io/badge/sops-3e484d?logo=gnuprivacyguard&logoColor=white&style=flat" />

---

[Forgejo Git Server](../forgejo/README.md) - [Back to home](../../README.md)

---

## Beschreibung

Dokumentation zur Einrichtung eines TrueNAS-Servers als iSCSI-Target sowie zur Anbindung der iSCSI-LUNs an Ubuntu und Fedora CoreOS Worker-Nodes.

---

## TrueNAS Server installieren und iSCSI Target einrichten

### VM

| Einstellung | Wert |
|---|---|
| Hostname | `nas.htdom.lan` |
| IP-Adresse | `192.168.178.70` |
| RAM | 4 GB |
| CPU | 2 vCPU |
| Disk | 10 GB |
| OS | Other |
| Betriebssystem | Other Linux (x64) |

Nach der Installation:

```text
http://192.168.178.xx

User: truenas_admin
Password: Passwort wird bei der Installation vergeben
```

---

## Storage einrichten

### Storage Pool

In TrueNAS:

```text
Storage
└── Create Pool
```

Einstellungen:

```text
Name:       k8s-pool
Layout:     Stripe
Disk Size:  25-50 GB
Width:      2
VDev:       1
```

Anschließend:

```text
Review
└── Create Pool
└── Confirm
```

### ZVOLs für die Kubernetes Worker

Zwei ZVOLs anlegen:

```text
Storage
└── k8s-pool
    └── Add Zvol
```

ZVOLs:

```text
lun-worker-1
lun-worker-2
```

Größe:

```text
ca. 95-98 %
```

Der verbleibende Speicher bleibt im Pool verfügbar.

Weitere Einstellungen auf Default belassen.

```text
Save
```

---

## iSCSI Share einrichten

In TrueNAS:

```text
Shares
└── Block (iSCSI) Shares
    └── Wizard
```

### Target

```text
Target:
    Create New
    Next
```

### Extent

Für die jeweiligen LUNs:

```text
Name:             lun-worker-1 / lun-worker-2
Extent Type:      Device
Device:           k8s-pool/lun-worker-1 / k8s-pool/lun-worker-2
Sharing Platform: Modern OS
```

### Protocol Options

```text
Create New

IP Address: 192.168.178.xx

Initiators:
    leer
```

Alternativ können hier die Server angegeben werden, die auf das iSCSI-Target zugreifen dürfen.

```text
Save
```

---

## Ubuntu Client mit iSCSI Target verbinden

### open-iscsi installieren

```bash
sudo apt update
sudo apt install open-iscsi -y
```

Services aktivieren:

```bash
sudo systemctl enable --now open-iscsi.service iscsid.service
```

### iSCSI Discovery

```bash
sudo iscsiadm -m discovery -t sendtargets -p 192.168.178.70
```

Beispiel:

```text
192.168.178.70:3260,1 iqn.2005-10.org.freenas.ctl:nas-iscsi
```

### Login

```bash
sudo iscsiadm -m node --login
```

Beispiel:

```text
Logging in to [iface: default, target: iqn.2005-10.org.freenas.ctl:nas-iscsi, portal: 192.168.178.70,3260]
Login to [iface: default, target: iqn.2005-10.org.freenas.ctl:nas-iscsi, portal: 192.168.178.70,3260] successful.
```

### Logout

```bash
sudo iscsiadm -m node --logout
```

Beispiel:

```text
Logging out of session [sid: 2, target: iqn.2005-10.org.freenas.ctl:nas-iscsi, portal: 192.168.178.70,3260]
Logout of [sid: 2, target: iqn.2005-10.org.freenas.ctl:nas-iscsi, portal: 192.168.178.70,3260] successful.
```

### Gezielt mit einem Target verbinden

```bash
sudo iscsiadm -m node -T "iqn.2005-10.org.freenas.ctl:nas-iscsi" -p 192.168.178.70 --login
```

Beispiel:

```text
Logging in to [iface: default, target: iqn.2005-10.org.freenas.ctl:nas-iscsi, portal: 192.168.178.70,3260]
Login to [iface: default, target: iqn.2005-10.org.freenas.ctl:nas-iscsi, portal: 192.168.178.70,3260] successful.
```

### Disk prüfen

```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
```

Beispiel:

```text
NAME                           SIZE TYPE  MOUNTPOINT
...
sda                             20G disk
nvme0n1                      931.5G disk
├─nvme0n1p1                      1G part  /boot/efi
├─nvme0n1p2                      2G part  /boot
...
```

### Dateisystem erstellen und mounten

```bash
sudo mkfs.ext4 /dev/sda
sudo mkdir -p /mnt/iscsi
sudo mount /dev/sda /mnt/iscsi
df -h
```

Testdatei anlegen:

```bash
sudo touch /mnt/iscsi/testfile
ls -lah /mnt/iscsi
```

Besitzer setzen:

```bash
sudo chown -R $USER:$USER /mnt/iscsi
```

---

## Kubernetes iSCSI LUNs

Für Kubernetes wurden zwei LUNs angelegt:

```bash
sudo iscsiadm -m discovery -t sendtargets -p 192.168.178.70
```

Ergebnis:

```text
192.168.178.70:3260,1 iqn.2005-10.org.freenas.ctl:lun-worker-1
192.168.178.70:3260,1 iqn.2005-10.org.freenas.ctl:lun-worker-2
```

Zuordnung:

| Kubernetes Node | iSCSI Target |
|---|---|
| `coreos-worker1` | `lun-worker-1` |
| `coreos-worker2` | `lun-worker-2` |

---

## Fedora CoreOS: iSCSI Initiator installieren

Auf Fedora CoreOS wird der iSCSI-Initiator als Layered Package installiert:

```bash
sudo rpm-ostree install iscsi-initiator-utils
```

Danach Neustart:

```bash
sudo reboot
```

Nach dem Neustart Services aktivieren:

```bash
sudo systemctl enable --now iscsid.service
sudo systemctl enable --now iscsi.service
```

---

## Worker-1

### iSCSI Target verbinden

```bash
sudo iscsiadm -m node -T iqn.2005-10.org.freenas.ctl:lun-worker-1 -v automatic -p 192.168.178.70 --login
```

Session prüfen:

```bash
sudo iscsiadm -m session
```

### Node-Konfiguration prüfen

```bash
sudo iscsiadm -m node -o show
```

Beispiel:

```text
# BEGIN RECORD 6.2.1.11
node.name = iqn.2005-10.org.freenas.ctl:lun-worker-1
node.tpgt = 1
node.startup = automatic
...
```

### Automatischen Start konfigurieren

Falls `node.startup` nicht auf `automatic` steht:

```bash
sudo iscsiadm -m node -T iqn.2005-10.org.freenas.ctl:lun-worker-1 -p 192.168.178.70 --op update -n node.startup -v automatic
```

### Achtung bei iSCSI Discovery

Bei einem:

```bash
sudo iscsiadm -m discovery
```

werden alle verfügbaren LUNs als Nodes gespeichert.

Wenn beispielsweise auf Worker-1 versehentlich auch `lun-worker-2` gespeichert wurde, kann der nicht benötigte Node wieder abgemeldet und gelöscht werden:

```bash
sudo iscsiadm -m node -T iqn.2005-10.org.freenas.ctl:lun-worker-2 -p 192.168.178.70 --logout
```

Danach:

```bash
sudo iscsiadm -m node -o delete -T iqn.2005-10.org.freenas.ctl:lun-worker-2 -p 192.168.178.70
```

### XFS Dateisystem erstellen

LUN prüfen:

```bash
lsblk
```

Dateisystem erstellen:

```bash
sudo mkfs.xfs /dev/sdb
```

Beispielausgabe:

```text
meta-data=/dev/sdb               isize=512    agcount=4, agsize=1310728 blks
         =                       sectsz=4096  attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=1
         =                       reflink=1    bigtime=1 inobtcount=1 nrext64=1
         =                       exchange=1   metadir=0
         =                       ...
```

Mountpoint erstellen:

```bash
sudo mkdir -p /var/lib/k8s-storage
```

UUID ermitteln:

```bash
sudo blkid
```

Beispiel:

```text
/dev/sdb: UUID="df337ade-f7a5-4b97-b77d-d85bba630578" BLOCK_SIZE="4096" TYPE="xfs"
```

### `/etc/fstab`

```bash
sudo vi /etc/fstab
```

Eintrag:

```text
UUID=df337ade-f7a5-4b97-b77d-d85bba630578 /var/lib/k8s-storage xfs defaults,_netdev 0 0
```

Systemd neu laden:

```bash
sudo systemctl daemon-reload
```

Mount testen:

```bash
sudo mount -a
```

Kontrolle:

```bash
lsblk
```

Beispiel:

```text
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   20G  0 disk
├─sda1   8:1    0    1M  0 part
...
sdb      8:16   0   20G  0 disk /var/lib/k8s-storage
```

---

## Worker-2

### iSCSI Target verbinden

```bash
sudo iscsiadm -m node -T iqn.2005-10.org.freenas.ctl:lun-worker-2 -p 192.168.178.70 --login
```

Session prüfen:

```bash
sudo iscsiadm -m session
```

Node-Konfiguration prüfen:

```bash
sudo iscsiadm -m node -o show
```

Beispiel:

```text
# BEGIN RECORD 6.2.1.11
node.name = iqn.2005-10.org.freenas.ctl:lun-worker-2
node.tpgt = 1
node.startup = automatic
...
```

### Automatischen Start konfigurieren

Falls `node.startup` nicht auf `automatic` steht:

```bash
sudo iscsiadm -m node -T iqn.2005-10.org.freenas.ctl:lun-worker-2 -p 192.168.178.70 --op update -n node.startup -v automatic
```

### Nicht benötigtes Target entfernen

Bei einer vorherigen Discovery können auch andere LUNs gespeichert worden sein.

Beispielsweise auf Worker-2 das nicht benötigte Worker-1 Target entfernen:

```bash
sudo iscsiadm -m node -T iqn.2005-10.org.freenas.ctl:lun-worker-1 -p 192.168.178.70 --logout
```

Danach:

```bash
sudo iscsiadm -m node -o delete -T iqn.2005-10.org.freenas.ctl:lun-worker-1 -p 192.168.178.70
```

### XFS Dateisystem erstellen

LUN prüfen:

```bash
lsblk
```

Dateisystem erstellen:

```bash
sudo mkfs.xfs /dev/sdb
```

Mountpoint erstellen:

```bash
sudo mkdir -p /var/lib/k8s-storage
```

UUID ermitteln:

```bash
sudo blkid
```

Beispiel:

```text
/dev/sdb: UUID="21978be0-240b-4168-9ebc-30d3aecf4975" BLOCK_SIZE="4096" TYPE="xfs"
```

### `/etc/fstab`

```bash
sudo vi /etc/fstab
```

Eintrag:

```text
UUID=21978be0-240b-4168-9ebc-30d3aecf4975 /var/lib/k8s-storage xfs defaults,_netdev 0 0
```

Systemd neu laden:

```bash
sudo systemctl daemon-reload
```

Mount testen:

```bash
sudo mount -a
```

Beispiel:

```text
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   20G  0 disk
├─sda1   8:1    0    1M  0 part
...
sdb      8:16   0   20G  0 disk /var/lib/k8s-storage
```

---

## Abschlussprüfung

Auf beiden Worker-Nodes prüfen.

### iSCSI Session

```bash
sudo iscsiadm -m session
```

### Block Device

```bash
lsblk
```

### Mount

```bash
findmnt /var/lib/k8s-storage
```

### `/etc/fstab`

```bash
cat /etc/fstab
```

Die jeweilige LUN sollte als:

```text
/dev/sdb
```

mit XFS-Dateisystem unter:

```text
/var/lib/k8s-storage
```

gemountet sein.

---

## Architektur

```text
                         TrueNAS
                     192.168.178.70
                           │
                     ┌─────┴─────┐
                     │ k8s-pool  │
                     │  Stripe   │
                     └─────┬─────┘
                           │
              ┌────────────┴────────────┐
              │                         │
        lun-worker-1              lun-worker-2
              │                         │
              │ iSCSI                   │ iSCSI
              ▼                         ▼
     coreos-worker1              coreos-worker2
     192.168.56.11              192.168.56.12
              │                         │
          /dev/sdb                  /dev/sdb
              │                         │
             XFS                       XFS
              │                         │
              ▼                         ▼
    /var/lib/k8s-storage       /var/lib/k8s-storage
```

Die LUNs werden auf den CoreOS-Nodes als XFS formatiert und anschließend über `/etc/fstab` dauerhaft eingebunden.

---

## Hinweise

- Die iSCSI-LUNs werden **nicht von Kubernetes formatiert**. Das Dateisystem wird auf dem jeweiligen CoreOS-Worker erstellt.
- Pro Worker wird eine eigene LUN verwendet.
- Es wird kein Multipath benötigt, da jede LUN nur von ihrem vorgesehenen Worker verwendet wird.
- Die Verwendung von `_netdev` in `/etc/fstab` stellt sicher, dass der Mount als netzwerkabhängig behandelt wird.
- Die aktuelle TrueNAS-Pool-Konfiguration verwendet `Stripe` ohne Redundanz und ist für das Homelab vorgesehen.
- Bei produktiven Systemen sollten Redundanz, Backup, Multipath und eine geeignete Storage-Architektur berücksichtigt werden.
