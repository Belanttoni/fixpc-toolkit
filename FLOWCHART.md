# FixPC Toolkit Flowcharts

## 1. High-level product flow

```mermaid
flowchart TD
    A[Start Application] --> B[Load Config and App State]
    B --> C[Load WinForms UI]
    C --> D[User Selects Modules]
    D --> E[User Selects Mode]
    E --> F[Run Workflow]
    F --> G[Collect Data]
    G --> H[Analyze Results]
    H --> I{Repair Mode?}
    I -- No --> J[Generate Reports]
    I -- Yes --> K[Execute Allowed Repairs]
    K --> J
    J --> L[Render Results in UI]
    L --> M[Open or Export Report]
    M --> N[End]
```

## 2. Internal architecture flow

```mermaid
flowchart TD
    UI[UI Layer] --> APP[Application / Workflow Layer]
    APP --> CORE[Core Services]
    APP --> SYS[System Module]
    APP --> NET[Network Module]
    APP --> HW[Hardware Module]
    SYS --> REP[Report Engine]
    NET --> REP
    HW --> REP
```

## 3. Standard module lifecycle

```mermaid
flowchart LR
    A[Definitions] --> B[Collect]
    B --> C[Analyze]
    C --> D{Selected Mode}
    D -- DiagnoseOnly --> E[Export]
    D -- SafeRepair --> F[Repair - Safe]
    D -- FullRepair --> G[Repair - Full]
    F --> E
    G --> E
```

## 4. Network diagnostic flow

```mermaid
flowchart TD
    A[Start Network Analysis] --> B[Collect Adapter Data]
    B --> C[Test Loopback]
    C --> D[Test Gateway]
    D --> E[Test Internet Reachability]
    E --> F[Test DNS Resolution]
    F --> G[Classify Failure Layer]
    G --> H[Generate Findings and Recommendations]
    H --> I{Repair Mode Enabled?}
    I -- No --> J[Export Network Result]
    I -- Yes --> K[Run Network Repair Policy]
    K --> J
```

## 5. System diagnostic flow

```mermaid
flowchart TD
    A[Start System Analysis] --> B[Collect OS and Health Data]
    B --> C[Analyze SFC and DISM State]
    C --> D[Analyze Storage and Temp Files]
    D --> E[Analyze Startup and Events]
    E --> F[Analyze Updates and Memory Indicators]
    F --> G[Generate Findings and Severity]
    G --> H{Repair Mode Enabled?}
    H -- No --> I[Export System Result]
    H -- Yes --> J[Run System Repair Policy]
    J --> I
```

## 6. Hardware diagnostic flow

```mermaid
flowchart TD
    A[Start Hardware Analysis] --> B[Collect BIOS and Board Data]
    B --> C[Collect Temperature Sensors]
    C --> D[Collect Fan and Storage Telemetry]
    D --> E[Analyze Thresholds]
    E --> F[Generate Warnings and Recommendations]
    F --> G[Export Hardware Result]
```

## 7. WinForms to WPF migration strategy

```mermaid
flowchart TD
    A[Current WinForms UI] --> B[Refactor Business Logic Out of Form]
    B --> C[Stabilize Workflow and Module Contracts]
    C --> D[Keep Core, Modules, Reports Unchanged]
    D --> E[Build WPF UI on Top of Existing Workflow]
    E --> F[Release V2 WPF]
```
