# GitHub Actions Workflow Architecture

Visual diagrams showing the CI/CD pipeline architecture, flow, and relationships.

## 📊 Workflow Architecture Overview

```mermaid
graph TB
    subgraph "GitHub Repository"
        A[Developer] -->|git push| B[Feature Branch]
        B -->|Create PR| C[Pull Request]
        C -->|Merge| D[Main Branch]
    end
    
    subgraph "GitHub Actions Triggers"
        C -->|Automatic| E[PR Trigger]
        D -->|Automatic| F[Push Trigger]
        G[Manual Action] -->|workflow_dispatch| H[Manual Trigger]
    end
    
    subgraph "Workflow Execution"
        E --> I[Plan on Dev]
        F --> J[Apply to Dev]
        H --> K[Plan/Apply/Destroy]
    end
    
    subgraph "Reusable Workflow"
        I --> L[reusable-terraform.yml]
        J --> L
        K --> L
    end
    
    subgraph "Terraform Operations"
        L --> M[Init]
        M --> N[Validate]
        N --> O[Plan]
        O --> P[Apply/Destroy]
    end
    
    subgraph "AWS Infrastructure"
        P --> Q[Networking Layer]
        P --> R[Security Layer]
        P --> S[Compute Layer]
        P --> T[Database Layer]
        P --> U[Storage Layer]
        P --> V[DNS Layer]
        P --> W[Monitoring Layer]
    end
    
    style L fill:#4CAF50
    style P fill:#2196F3
    style A fill:#FF9800
```

## 🔄 Layer Deployment Flow

```mermaid
graph LR
    A[1. Networking] --> B[2. Security]
    B --> C[3. Storage]
    C --> D[4. Database]
    D --> E[5. Compute]
    E --> F[6. DNS]
    F --> G[7. Monitoring]
    
    style A fill:#4CAF50
    style B fill:#2196F3
    style C fill:#9C27B0
    style D fill:#FF9800
    style E fill:#F44336
    style F fill:#00BCD4
    style G fill:#FFEB3B
```

## 🎯 Trigger Types and Behavior

```mermaid
graph TB
    subgraph "Trigger Events"
        A[Pull Request]
        B[Push to Main]
        C[Manual Dispatch]
    end
    
    subgraph "Automatic Actions"
        A --> D[Run Plan on Dev]
        B --> E[Run Apply on Dev]
        D --> F[Comment on PR]
    end
    
    subgraph "Manual Actions"
        C --> G{Select Action}
        G -->|Plan| H[Generate Plan]
        G -->|Apply| I[Deploy Infrastructure]
        G -->|Destroy| J[Remove Infrastructure]
    end
    
    subgraph "Environment Selection"
        G --> K{Select Environment}
        K --> L[Dev]
        K --> M[QA]
        K --> N[UAT]
        K --> O[Prod]
    end
    
    style A fill:#4CAF50
    style B fill:#2196F3
    style C fill:#FF9800
```

## 🔐 Environment Protection Flow

```mermaid
graph TB
    A[Deployment Request] --> B{Environment?}
    
    B -->|Dev| C[No Approval]
    C --> D[Deploy Immediately]
    
    B -->|QA| E[No Approval]
    E --> F[Deploy Immediately]
    
    B -->|UAT| G[1 Reviewer Required]
    G --> H{Approved?}
    H -->|Yes| I[Deploy]
    H -->|No| J[Blocked]
    
    B -->|Prod| K[2 Reviewers + Wait Timer]
    K --> L{Approved?}
    L -->|Yes| M[Wait 10 min]
    M --> N[Deploy]
    L -->|No| O[Blocked]
    
    style C fill:#4CAF50
    style E fill:#4CAF50
    style G fill:#FF9800
    style K fill:#F44336
```

## 📦 Workflow File Structure

```mermaid
graph TB
    subgraph "Core Workflow"
        A[reusable-terraform.yml]
    end
    
    subgraph "Layer Workflows"
        B[deploy-networking.yml]
        C[deploy-security.yml]
        D[deploy-compute.yml]
        E[deploy-database.yml]
        F[deploy-storage.yml]
        G[deploy-dns.yml]
        H[deploy-monitoring.yml]
    end
    
    subgraph "Orchestration"
        I[deploy-all-layers.yml]
    end
    
    B --> A
    C --> A
    D --> A
    E --> A
    F --> A
    G --> A
    H --> A
    I --> B
    I --> C
    I --> D
    I --> E
    I --> F
    I --> G
    I --> H
    
    style A fill:#4CAF50
    style I fill:#2196F3
```

## 🔄 Complete Deployment Workflow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Git as GitHub
    participant GHA as GitHub Actions
    participant TF as Terraform
    participant AWS as AWS
    
    Dev->>Git: Push to feature branch
    Dev->>Git: Create Pull Request
    Git->>GHA: Trigger PR workflow
    GHA->>TF: terraform plan (dev)
    TF->>AWS: Preview changes
    TF-->>GHA: Plan output
    GHA->>Git: Comment on PR
    
    Dev->>Git: Review & Merge PR
    Git->>GHA: Trigger push workflow
    GHA->>TF: terraform apply (dev)
    TF->>AWS: Deploy changes
    AWS-->>TF: Resources created
    TF-->>GHA: Apply complete
    GHA->>Git: Update status
    
    Dev->>GHA: Manual trigger (prod)
    GHA->>Git: Request approval
    Git-->>GHA: Approved
    GHA->>TF: terraform apply (prod)
    TF->>AWS: Deploy to production
    AWS-->>TF: Resources created
    TF-->>GHA: Deployment complete
```

## 🎬 Layer Deployment Sequence

```mermaid
sequenceDiagram
    participant Orchestrator as Deploy All Layers
    participant Net as Networking
    participant Sec as Security
    participant Stor as Storage
    participant DB as Database
    participant Comp as Compute
    participant DNS as DNS
    participant Mon as Monitoring
    
    Orchestrator->>Net: Deploy Layer 1
    Net-->>Orchestrator: ✓ Complete
    
    Orchestrator->>Sec: Deploy Layer 2
    Sec-->>Orchestrator: ✓ Complete
    
    Orchestrator->>Stor: Deploy Layer 3
    Stor-->>Orchestrator: ✓ Complete
    
    Orchestrator->>DB: Deploy Layer 4
    DB-->>Orchestrator: ✓ Complete
    
    Orchestrator->>Comp: Deploy Layer 5
    Comp-->>Orchestrator: ✓ Complete
    
    Orchestrator->>DNS: Deploy Layer 6
    DNS-->>Orchestrator: ✓ Complete
    
    Orchestrator->>Mon: Deploy Layer 7
    Mon-->>Orchestrator: ✓ Complete
    
    Note over Orchestrator: All layers deployed successfully
```

## 🔀 Branching and Deployment Strategy

```mermaid
gitGraph
    commit id: "Initial"
    branch develop
    checkout develop
    commit id: "Feature work"
    branch feature/vpc-update
    checkout feature/vpc-update
    commit id: "Update VPC CIDR"
    commit id: "Add endpoints"
    checkout develop
    merge feature/vpc-update
    checkout main
    merge develop tag: "Auto-deploy to Dev"
    commit id: "Manual QA deploy" type: HIGHLIGHT
    commit id: "Manual UAT deploy" type: HIGHLIGHT
    commit id: "Manual Prod deploy" type: REVERSE
```

## 🏗️ Infrastructure Layer Dependencies

```mermaid
graph TD
    A[Networking Layer] --> B[Security Layer]
    A --> C[Storage Layer]
    B --> D[Database Layer]
    C --> D
    B --> E[Compute Layer]
    D --> E
    A --> F[DNS Layer]
    E --> F
    E --> G[Monitoring Layer]
    F --> G
    
    style A fill:#4CAF50
    style B fill:#2196F3
    style C fill:#9C27B0
    style D fill:#FF9800
    style E fill:#F44336
    style F fill:#00BCD4
    style G fill:#FFEB3B
```

## 📈 Workflow Execution Steps

```mermaid
graph TB
    A[Workflow Triggered] --> B[Checkout Code]
    B --> C[Configure AWS Credentials]
    C --> D[Setup Terraform]
    D --> E[Terraform Format Check]
    E --> F[Terraform Init]
    F --> G[Terraform Validate]
    G --> H{Action Type?}
    
    H -->|Plan| I[Generate Plan]
    I --> J[Upload Plan Artifact]
    J --> K[Comment on PR]
    
    H -->|Apply| L[Generate Plan]
    L --> M[Execute Apply]
    M --> N[Update Infrastructure]
    
    H -->|Destroy| O[Execute Destroy]
    O --> P[Remove Resources]
    
    N --> Q[Generate Summary]
    P --> Q
    K --> Q
    Q --> R[Workflow Complete]
    
    style A fill:#4CAF50
    style H fill:#FF9800
    style R fill:#2196F3
```

## 🔒 Security and Access Control

```mermaid
graph TB
    subgraph "GitHub Access"
        A[Developer] --> B{Role?}
        B -->|Admin| C[Full Access]
        B -->|Write| D[PR + Merge]
        B -->|Read| E[View Only]
    end
    
    subgraph "Environment Protection"
        C --> F{Environment}
        D --> F
        F -->|Dev| G[No Restrictions]
        F -->|QA| H[No Restrictions]
        F -->|UAT| I[1 Approval]
        F -->|Prod| J[2 Approvals]
    end
    
    subgraph "AWS Access"
        G --> K[AWS Credentials]
        H --> K
        I --> K
        J --> K
        K --> L[IAM Permissions]
        L --> M[Deploy Resources]
    end
    
    style J fill:#F44336
    style I fill:#FF9800
    style G fill:#4CAF50
```

---

## 📝 Diagram Legend

| Symbol | Meaning |
|--------|---------|
| 🟢 Green | Safe/Approved |
| 🔵 Blue | In Progress |
| 🟡 Yellow | Needs Review |
| 🔴 Red | Critical/Prod |
| 🟣 Purple | Storage |
| 🟠 Orange | Warning |

## 🔗 Related Documentation

- [Complete CI/CD Guide](CICD.md)
- [Quick Start Guide](CICD-QUICKSTART.md)
- [Workflow README](../.github/workflows/README.md)

---

**Note**: These diagrams use Mermaid syntax and will render in GitHub, VS Code with Mermaid extension, or any Mermaid-compatible viewer.

**Last Updated**: October 2025  
**Maintained By**: Platform Engineering Team
