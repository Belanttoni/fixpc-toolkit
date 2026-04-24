# FixPC Toolkit

FixPC Toolkit is a modular Windows diagnostic and repair tool designed for real-world technical support scenarios.

It provides fast system analysis, intelligent diagnostics, and safe automated repair actions — with a clean HTML report for documentation.

---

## 🚀 Features

### 🔧 Hardware Diagnostics

* CPU / RAM / Disk inventory
* SMART disk health analysis
* NVMe / storage temperature monitoring
* Battery health classification (Healthy / Degraded / Poor)
* Graceful fallback when CPU temperature is unavailable
* Detection of missing sensor providers (LHM/OHM)

---

### 🌐 Network Diagnostics

* Smart primary adapter detection (no VPN/TAP false selection)
* Wi-Fi SSID identification
* DHCP vs Static IP detection
* APIPA detection (only on primary adapter — no false positives)
* Connectivity validation using:

  * DNS resolution
  * TCP (port 443)
* Intelligent handling of ICMP-blocked environments

  * No false "no internet" alerts

---

### 🛠️ Network Repair (SafeRepair Mode)

* DNS cache flush
* DHCP release / renew
* Adapter restart (targeted)
* Winsock / TCP stack reset (FullRepair only)
* Action tracking with detailed results

---

### 📊 Reports

* Clean HTML diagnostic report
* Technician-friendly layout
* Connectivity matrix (real interpretation, not raw ICMP)
* Repair actions summary
* Battery health and hardware insights

---

## ▶️ Usage

Run the toolkit:

```powershell
.\FixPC-Toolkit.ps1
```

---

## ⚙️ Execution Policy (if needed)

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 🧱 Project Structure

```
FixPC-Toolkit/
│
├── App/
├── Core/
├── Modules/
│   ├── Hardware/
│   └── Network/
├── Reports/
├── Tests/
├── UI/
├── UI.WinForms/
├── UI.WPF/
│
├── FixPC-Toolkit.ps1
├── README.md
```

---

## 📦 Requirements

* Windows 10 / 11
* PowerShell 5+
* Administrator privileges (recommended for full functionality)

---

## ⚠️ Alpha Status

This is an **alpha release**, intended for controlled testing.

### Known limitations

* CPU temperature depends on external sensor providers (e.g. LibreHardwareMonitor)
* Some repair actions require administrator privileges
* Hardware sensor availability varies by system

---

## 🧠 Design Philosophy

FixPC Toolkit is built to:

* Avoid false positives (especially network diagnostics)
* Provide actionable results, not raw data
* Work in real technician environments (VPNs, ICMP blocks, etc.)
* Be modular and extensible

---

## 🗺️ Roadmap

* Improve CPU temperature detection reliability
* Expand repair modules (disk, services, Windows components)
* Enhance HTML report
* WPF interface (planned)
* Packaging / installer

---

## 📌 Versioning

Current version:

```
v1.0.0-alpha
```

---

## 👨‍💻 Author

Developed by Belantoni
FixPC Consultoria de TI

---

## 📄 License

(define your license here — MIT recommended)
