# Network Module Scope

## Purpose
This document defines the scope of the Network module for FixPC Toolkit V1.

## Module Identity
The Network module is responsible for connectivity diagnosis, adapter state inspection, layered reachability testing, and controlled network repair workflows.

## Primary Goal
Provide clear and structured identification of network-related failures and support safe corrective actions.

## Internal Lifecycle
The Network module follows the standard lifecycle:
- Collect
- Analyze
- Repair
- Export

## Collect Scope
The Network module may collect the following information in V1:

- network adapter inventory
- adapter enable/disable state
- IP address information
- subnet information
- gateway information
- DNS server configuration
- adapter operational status
- loopback reachability
- default gateway reachability
- public internet reachability
- DNS resolution success or failure
- optional latency indicators
- optional packet loss indicators
- proxy-related configuration overview where feasible

## Analyze Scope
The Network module must analyze findings such as:

- adapter disconnected state
- missing IP configuration
- missing default gateway
- loopback failure
- gateway failure
- internet reachability failure
- DNS resolution failure
- DNS misconfiguration indicators
- unstable network path indicators
- probable local-only connectivity
- probable DNS-only failure
- probable WAN or upstream failure

## Layered Diagnostic Model
The Network module should follow a layered model in V1:

1. Adapter state
2. Loopback test
3. Local IP presence
4. Gateway reachability
5. Internet reachability
6. DNS resolution

This layered model helps classify failures more accurately.

## Repair Scope
The Network module supports the following repair categories in V1:

### SafeRepair
Allowed examples:
- DNS cache flush
- lightweight IP renewal workflows
- low-risk adapter refresh workflows
- informational corrective recommendations

### FullRepair
Allowed examples:
- Winsock reset
- TCP/IP reset
- deeper adapter reset workflows
- stronger connectivity remediation actions

## Export Scope
The Network module must export:

- connection status summary
- test-by-test outcome summary
- probable failure classification
- recommendations
- actions taken
- severity
- report-friendly output for HTML, TXT, and JSON

## Severity Guidelines

### ok
Network state appears healthy.

### info
Network state is operational and only informational details are present.

### warn
A relevant but non-critical issue exists.
Examples:
- DNS delay
- intermittent adapter instability
- optional path quality degradation

### error
A significant network issue exists.
Examples:
- no gateway reachability
- internet unreachable
- DNS failure with user impact

### critical
A severe connectivity failure exists.
Examples:
- complete connectivity breakdown
- repeated local network failure
- unusable network state after controlled checks

## V1 Boundaries
The Network module in V1 does not aim to:
- replace enterprise network monitoring solutions
- manage routers, switches, or firewalls centrally
- perform unrestricted network reconfiguration
- diagnose every advanced VPN or domain scenario

## V1 Success Criteria
The Network module is considered structurally ready when:
- the layered diagnostic model is documented
- repair actions are separated into safe and full categories
- collection, analysis, and export scope are defined
- severity mapping is defined

## Future Direction
Future versions may expand this module to include:
- Wi-Fi quality analysis
- VPN awareness
- domain and DNS suffix analysis
- route table inspection
- RDP and printer connectivity helpers
- richer latency and packet loss reporting