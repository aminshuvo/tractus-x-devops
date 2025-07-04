# Architecture Documentation

This document describes the system architecture, design decisions, and technical implementation of the Tractus-X DevOps deployment.

## System Overview

The Tractus-X deployment consists of multiple interconnected components deployed on Kubernetes with comprehensive observability and GitOps-based management. The architecture follows cloud-native principles with microservices design, enabling scalability, resilience, and maintainability.

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Access Layer                    │
├─────────────┬─────────────┬─────────────┬─────────────┤
│   Portal    │   ArgoCD    │   Grafana   │ Prometheus  │
│     UI      │     UI      │     UI      │     UI      │
└─────────────┴─────────────┴─────────────┴─────────────┘
             │
┌─────────────────────────────────────────────────────────┐
│                   Ingress Controller                    │
│                  (Nginx Ingress)                       │
│             TLS Termination & Routing                  │
└─────────────────────────────────────────────────────────┘
             │
┌─────────────────────────────────────────────────────────┐
│                 Kubernetes Cluster                      │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐    │
│  │ Tractus-X   │ │     EDC     │ │   Monitoring    │    │
│  │ Namespace   │ │ Standalone  │ │   Namespace     │    │
│  │             │ │ Namespace   │ │                 │    │
│  │ • Portal    │ │ • Control   │ │ • Prometheus    │    │
│  │ • IAM       │ │   Plane     │ │ • Grafana       │    │
│  │ • Discovery │ │ • Data      │ │ • Loki          │    │
│  │ • EDC       │ │   Plane     │ │ • Alertmanager  │    │
│  └─────────────┘ └─────────────┘ └─────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              ArgoCD Namespace                       │ │
│  │  • Application Controller                           │ │
│  │  • Repository Server                               │ │
│  │  • Server                                          │ │
│  │  • Redis                                           │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
             │
┌─────────────────────────────────────────────────────────┐
│                  Persistent Storage                     │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐    │
│  │ PostgreSQL  │ │   Redis     │ │   File System   │    │
│  │ Database    │ │   Cache     │ │   Storage       │    │
│  └─────────────┘ └─────────────┘ └─────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### Component Architecture

#### Tractus-X Umbrella Project

The Tractus-X umbrella includes core components for data space management:

- **Portal**: React-based web interface for data space participants
  - User registration and authentication
  - Company and service catalog management
  - App marketplace and subscription management
  - Digital identity wallet integration

- **IAM Service (Keycloak)**: Identity and access management
  - User authentication and authorization
  - OAuth 2.0 / OpenID Connect provider
  - Role-based access control (RBAC)
  - Federation with external identity providers

- **Discovery Service**: Service and endpoint discovery
  - Service registry for data space participants
  - Endpoint discovery and connectivity testing
  - Service health monitoring
  - API documentation aggregation

- **EDC Connector (Embedded)**: Tractus-X integrated data connector
  - Built-in connector for portal integration
  - Simplified configuration and management
  - Direct integration with IAM service
  - Portal-based contract management

#### Standalone EDC Components

Independent EDC deployment demonstrating peer-to-peer integration:

- **Control Plane**: Contract negotiation and management
  - Contract definition and policy management
  - Negotiation state machine
  - Asset catalog management
  - Transfer process orchestration

- **Data Plane**: Actual data transfer operations
  - Data routing and transformation
  - Protocol adaptation (HTTP, S3, etc.)
  - Transfer progress monitoring
  - Data validation and integrity checks

- **Management API**: Administrative interface
  - RESTful API for connector management
  - Asset and policy CRUD operations
  - Contract and transfer monitoring
  - Configuration management

#### Observability Stack

Comprehensive monitoring and logging infrastructure:

- **Prometheus**: Metrics collection and alerting
  - Time-series metrics storage
  - Service discovery and auto-configuration
  - Alert rule evaluation and notification
  - Federation support for multi-cluster deployments

- **Grafana**: Visualization and dashboards
  - Real-time dashboard rendering
  - Alert visualization and management
  - Data source integration (Prometheus, Loki)
  - User and team management

- **Loki**: Log aggregation and querying
  - Distributed log aggregation
  - Label-based log indexing
  - LogQL query language
  - Integration with Grafana for visualization

- **Promtail**: Log collection agent
  - Kubernetes pod log discovery
  - Log parsing and labeling
  - Multi-tenant log shipping
  - Pipeline processing stages

#### GitOps Management

Continuous deployment and configuration management:

- **ArgoCD**: Continuous deployment and GitOps
  - Git repository synchronization
  - Declarative application management
  - Multi-cluster deployment support
  - RBAC and policy enforcement

- **Applications**: Declarative application definitions
  - Helm chart integration
  - Kustomize overlay support
  - Health status monitoring
  - Rollback capabilities

- **Projects**: Multi-tenancy and access control
  - Repository access control
  - Destination cluster restrictions
  - Resource quotas and limits
  - Team-based access management

## Design Principles

### Infrastructure as Code (IaC)

All infrastructure components are defined as code to ensure:

- **Reproducibility**: Identical environments across dev/staging/production
- **Version Control**: All changes tracked in Git
- **Automation**: Reduced manual intervention and human error
- **Documentation**: Infrastructure serves as living documentation

**Tools Used:**
- **Terraform**: Infrastructure provisioning and management
- **Helm Charts**: Kubernetes application packaging and templating
- **Kustomize**: Configuration customization and overlay management
- **ArgoCD**: GitOps-based deployment automation

### Microservices Architecture

Services are designed as loosely coupled microservices:

- **Independent Deployment**: Each service can be deployed separately
- **Technology Diversity**: Different services can use different tech stacks
- **Failure Isolation**: Failures in one service don't cascade
- **Team Autonomy**: Different teams can own different services

**Communication Patterns:**
- **Synchronous**: REST APIs for request-response interactions
- **Asynchronous**: Message queues for event-driven communication
- **Service Discovery**: Kubernetes DNS for service resolution
- **Load Balancing**: Kubernetes services with multiple replicas

### Observability First

Comprehensive observability built into the system from the ground up:

- **Metrics**: Quantitative measurements of system behavior
- **Logs**: Detailed records of system events and transactions
- **Traces**: Request flow tracking across service boundaries
- **Health Checks**: Proactive system health monitoring

**Three Pillars Implementation:**
- **Metrics**: Prometheus with custom metrics for business logic
- **Logs**: Structured logging with correlation IDs
- **Traces**: OpenTelemetry integration (optional, configurable)

### Security by Design

Security considerations integrated throughout the architecture:

- **Defense in Depth**: Multiple layers of security controls
- **Least Privilege**: Minimal required permissions for each component
- **Encryption**: Data encrypted in transit and at rest
- **Audit Trail**: Comprehensive logging of security events

**Security Layers:**
- **Network Security**: Network policies and service mesh
- **Identity Security**: OAuth/OIDC with RBAC
- **Data Security**: Encryption and data classification
- **Application Security**: Security scanning and vulnerability management

## Detailed Component Specifications

### Tractus-X Portal Architecture

```
┌─────────────────────────────────────────────────────────┐
│                 Tractus-X Portal                        │
│                                                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐    │
│  │  Frontend   │ │   Backend   │ │     Database    │    │
│  │   (React)   │ │  (Spring)   │ │  (PostgreSQL)   │    │
│  │             │ │             │ │                 │    │
│  │ • UI/UX     │ │ • REST API  │ │ • User Data     │    │
│  │ • State Mgmt│ │ • Business  │ │ • Company Data  │    │
│  │ • Routing   │ │   Logic     │ │ • App Registry  │    │
│  │ • Auth      │ │ • Data      │ │ • Audit Logs    │    │
│  │   Handling  │ │   Access    │ │                 │    │
│  └─────────────┘ └─────────────┘ └─────────────────┘    │
│         │               │                   │           │
│         └───────────────┼───────────────────┘           │
│                         │                               │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              Integration Layer                       │ │
│  │  • IAM Integration (Keycloak)                       │ │
│  │  • EDC Connector API                               │ │
│  │  • Discovery Service API                           │ │
│  │  • External Service APIs                           │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Technology Stack:**
- **Frontend**: React 18, TypeScript, Material-UI
- **Backend**: Spring Boot 3, Java 17, Spring Security
- **Database**: PostgreSQL 15 with connection pooling
- **Caching**: Redis for session storage and caching
- **Authentication**: OAuth 2.0 / OpenID Connect via Keycloak

**Key Features:**
- Single Sign-On (SSO) integration
- Multi-tenant architecture
- Responsive web design
- API-first design
- Role-based access control

### EDC Connector Architecture

```
┌─────────────────────────────────────────────────────────┐
│                 EDC Connector                           │
│                                                         │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                Control Plane                        │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐    │ │
│  │  │ Management  │ │ Protocol    │ │   Policy    │    │ │
│  │  │     API     │ │   Engine    │ │   Engine    │    │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘    │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐    │ │
│  │  │ Contract    │ │ Asset Mgmt  │ │ Transfer    │    │ │
│  │  │    Mgmt     │ │             │ │   Process   │    │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘    │ │
│  └─────────────────────────────────────────────────────┘ │
│                         │                               │
│                         ▼                               │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                 Data Plane                          │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐    │ │
│  │  │ Data Plane  │ │ Data Source │ │ Data Sink   │    │ │
│  │  │   Gateway   │ │  Adapters   │ │  Adapters   │    │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘    │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐    │ │
│  │  │   Token     │ │   Transfer  │ │ Monitoring  │    │ │
│  │  │ Validation  │ │   Manager   │ │ & Metrics   │    │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘    │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**EDC Control Plane Components:**
- **Management API**: RESTful interface for connector configuration
- **Protocol Engine**: Implements Dataspace Protocol for inter-connector communication
- **Policy Engine**: Evaluates data access policies and usage constraints
- **Contract Management**: Handles contract negotiation lifecycle
- **Asset Management**: Manages data asset catalog and metadata
- **Transfer Process Manager**: Orchestrates data transfer workflows

**EDC Data Plane Components:**
- **Data Plane Gateway**: Entry point for data transfer requests
- **Data Source Adapters**: Protocol-specific adapters (HTTP, S3, Azure Blob, etc.)
- **Data Sink Adapters**: Output adapters for various destination types
- **Token Validation**: Validates transfer tokens and authorization
- **Transfer Manager**: Manages actual data transfer operations
- **Monitoring & Metrics**: Tracks transfer progress and performance

### Monitoring Architecture

```
┌─────────────────────────────────────────────────────────┐
│                Monitoring Stack                         │
│                                                         │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                 Metrics Layer                       │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐    │ │
│  │  │ Prometheus  │ │   Node      │ │   Kube      │    │ │
│  │  │   Server    │ │  Exporter   │ │  State      │    │ │
│  │  │             │ │             │ │  Metrics    │    │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘    │ │
│  └─────────────────────────────────────────────────────┘ │
│                         │                               │
│                         ▼                               │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              Visualization Layer                    │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐    │ │
│  │  │   Grafana   │ │ Dashboards  │ │ Alertmanager│    │ │
│  │  │   Server    │ │             │ │             │    │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘    │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                         │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                Logging Layer                        │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐    │ │
│  │  │    Loki     │ │  Promtail   │ │  Log Mgmt   │    │ │
│  │  │   Server    │ │   Agent     │ │             │    │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘    │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Monitoring Components:**
- **Prometheus Server**: Metrics collection, storage, and alerting
- **Node Exporter**: System-level metrics from Kubernetes nodes
- **Kube State Metrics**: Kubernetes cluster state metrics
- **Grafana Server**: Dashboard visualization and user interface
- **Alertmanager**: Alert routing, grouping, and notification
- **Loki Server**: Log aggregation and storage
- **Promtail Agent**: Log collection from Kubernetes pods

## Data Flow

### EDC Data Exchange Flow

```
┌─────────────┐              ┌─────────────┐
│  Consumer   │   Discovery  │  Provider   │
│     EDC     │◄────────────►│     EDC     │
│             │              │             │
│             │   Contract   │             │
│             │ Negotiation  │             │
│             │◄────────────►│             │
│             │              │             │
│             │   Data       │             │
│             │  Transfer    │             │
│             │◄────────────►│             │
└─────────────┘              └─────────────┘
       │                            │
       ▼                            ▼
┌─────────────┐              ┌─────────────┐
│   Data      │              │   Data      │
│ Consumer    │              │ Provider    │
│ System      │              │ System      │
└─────────────┘              └─────────────┘
```

**Data Exchange Steps:**

1. **Discovery Phase**
   - Consumer queries provider's catalog
   - Provider returns available datasets and services
   - Consumer evaluates available offerings

2. **Contract Negotiation Phase**
   - Consumer initiates contract negotiation
   - Provider evaluates request against policies
   - Both parties agree on terms and conditions
   - Contract agreement is established

3. **Data Transfer Phase**
   - Consumer initiates transfer request
   - Provider validates request and authorization
   - Data plane establishes secure data channel
   - Data is transferred with monitoring and validation

4. **Monitoring and Compliance**
   - Transfer progress is monitored
   - Usage policies are enforced
   - Audit logs are generated
   - Compliance reporting is updated

### Monitoring Data Flow

```
┌─────────────┐   Metrics   ┌─────────────┐
│ Application │────────────►│ Prometheus  │
│   Services  │             │   Server    │
└─────────────┘             └─────────────┘
       │                           │
       │ Logs                      │ Queries
       ▼                           ▼
┌─────────────┐             ┌─────────────┐
│   Promtail  │────────────►│   Grafana   │
│    Agent    │    Logs     │   Server    │
└─────────────┘             └─────────────┘
       │                           │
       ▼                           │
┌─────────────┐                    │
│    Loki     │◄───────────────────┘
│   Server    │    Log Queries
└─────────────┘
       │
       ▼
┌─────────────┐
│   Alert     │
│  Manager    │
└─────────────┘
```

**Data Flow Components:**

1. **Metrics Collection**
   - Applications expose metrics endpoints
   - Prometheus scrapes metrics from endpoints
   - Metrics are stored in time-series database
   - Alert rules are evaluated continuously

2. **Log Collection**
   - Promtail agents collect logs from containers
   - Logs are parsed and labeled
   - Structured logs are sent to Loki
   - Log retention policies are applied

3. **Visualization**
   - Grafana queries Prometheus for metrics
   - Grafana queries Loki for logs
   - Dashboards render real-time visualizations
   - Alerts are displayed and managed

4. **Alerting**
   - Alert rules trigger based on metrics
   - Alertmanager handles alert routing
   - Notifications sent via multiple channels
   - Alert fatigue is managed through grouping

## Network Architecture

### Namespace Segmentation

```
┌─────────────────────────────────────────────────────────┐
│                 Kubernetes Cluster                      │
│                                                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐    │
│  │ tractus-x   │ │edc-standalone│ │   monitoring    │    │
│  │ namespace   │ │  namespace   │ │   namespace     │    │
│  │             │ │             │ │                 │    │
│  │ ┌─────────┐ │ │ ┌─────────┐ │ │ ┌─────────────┐ │    │
│  │ │ Portal  │ │ │ │ EDC-CP  │ │ │ │ Prometheus  │ │    │
│  │ └─────────┘ │ │ └─────────┘ │ │ └─────────────┘ │    │
│  │ ┌─────────┐ │ │ ┌─────────┐ │ │ ┌─────────────┐ │    │
│  │ │   IAM   │ │ │ │ EDC-DP  │ │ │ │   Grafana   │ │    │
│  │ └─────────┘ │ │ └─────────┘ │ │ └─────────────┘ │    │
│  │ ┌─────────┐ │ │             │ │ ┌─────────────┐ │    │
│  │ │EDC-Embed│ │ │             │ │ │    Loki     │ │    │
│  │ └─────────┘ │ │             │ │ └─────────────┘ │    │
│  └─────────────┘ └─────────────┘ └─────────────────┘    │
│         │               │                   │           │
│         └───────────────┼───────────────────┘           │
│                         │                               │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                argocd namespace                     │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐    │ │
│  │  │   Server    │ │ App Control │ │ Repo Server │    │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘    │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Network Segmentation Benefits:**
- **Isolation**: Logical separation of application components
- **Security**: Network policies control inter-namespace communication
- **Resource Management**: Namespace-level resource quotas and limits
- **Access Control**: RBAC permissions scoped to namespaces

### Service Communication

```
Application Layer:
┌─────────────┐    HTTP/HTTPS   ┌─────────────┐
│   Portal    │◄───────────────►│     IAM     │
│   Frontend  │                 │ (Keycloak)  │
└─────────────┘                 └─────────────┘
       │                               │
       │ REST API                      │ OAuth/OIDC
       ▼                               ▼
┌─────────────┐    HTTP/HTTPS   ┌─────────────┐
│   Portal    │◄───────────────►│ Discovery   │
│   Backend   │                 │  Service    │
└─────────────┘                 └─────────────┘
       │                               │
       │ EDC Management API            │
       ▼                               ▼
┌─────────────┐  Dataspace Protocol  ┌─────────────┐
│ EDC Control │◄────────────────────►│ EDC Control │
│    Plane    │                     │    Plane    │
│ (Embedded)  │                     │(Standalone) │
└─────────────┘                     └─────────────┘
       │                               │
       │ Control API                   │ Control API
       ▼                               ▼
┌─────────────┐    Data Transfer    ┌─────────────┐
│ EDC Data    │◄───────────────────►│ EDC Data    │
│    Plane    │                     │    Plane    │
│ (Embedded)  │                     │(Standalone) │
└─────────────┘                     └─────────────┘
```

**Communication Protocols:**
- **HTTP/HTTPS**: Standard web traffic and API communication
- **Dataspace Protocol**: EDC-specific protocol for connector communication
- **OAuth/OIDC**: Authentication and authorization flows
- **gRPC**: High-performance internal service communication (optional)

### Ingress Configuration

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│              Cloud Load Balancer                        │
│            (Cloud Provider LB)                         │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│              Nginx Ingress Controller                   │
│                                                         │
│  Rules:                                                 │
│  • tractus-x.example.com → Portal Service              │
│  • argocd.example.com → ArgoCD Service                 │
│  • grafana.example.com → Grafana Service               │
│  • prometheus.example.com → Prometheus Service         │
│  • edc-api.example.com → EDC Management API            │
└─────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│              Kubernetes Services                        │
│                                                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐    │
│  │   Portal    │ │   ArgoCD    │ │   Monitoring    │    │
│  │   Service   │ │   Service   │ │   Services      │    │
│  └─────────────┘ └─────────────┘ └─────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Storage Architecture

### Persistent Storage Strategy

```
┌─────────────────────────────────────────────────────────┐
│                Storage Architecture                     │
│                                                         │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                Application Data                     │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐    │ │
│  │  │ PostgreSQL  │ │   Redis     │ │ File System │    │ │
│  │  │ Database    │ │   Cache     │ │   Storage   │    │ │
│  │  │             │ │             │ │             │    │ │
│  │  │ • User Data │ │ • Sessions  │ │ • Logs      │    │ │
│  │  │ • Contracts │ │ • Cache     │ │ • Backups   │    │ │
│  │  │ • Assets    │ │ • Temp Data │ │ • Artifacts │    │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘    │ │
│  └─────────────────────────────────────────────────────┘ │
│                         │                               │
│                         ▼                               │
│  ┌─────────────────────────────────────────────────────┐ │
│  │               Storage Classes                       │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐    │ │
│  │  │   Fast SSD  │ │  Standard   │ │  Archive    │    │ │
│  │  │             │ │   Storage   │ │  Storage    │    │ │
│  │  │ • Database  │ │ • App Data  │ │ • Backups   │    │ │
│  │  │ • Cache     │ │ • Logs      │ │ • Archives  │    │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘    │ │
│  └─────────────────────────────────────────────────────┘ │
│                         │                               │
│                         ▼                               │
│  ┌─────────────────────────────────────────────────────┐ │
│  │          Underlying Infrastructure                  │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐    │ │
│  │  │  Local SSD  │ │ Network     │ │  Cloud      │    │ │
│  │  │             │ │ Storage     │ │ Storage     │    │ │
│  │  │ • Minikube  │ │ • NFS/iSCSI │ │ • AWS EBS   │    │ │
│  │  │ • HostPath  │ │ • Ceph      │ │ • GCP PD    │    │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘    │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Storage Classification:**

1. **Database Storage (High Performance)**
   - **Type**: Fast SSD storage
   - **Use Cases**: PostgreSQL databases, Redis cache
   - **Requirements**: Low latency, high IOPS
   - **Backup**: Daily automated backups

2. **Application Storage (Standard)**
   - **Type**: Standard persistent storage
   - **Use Cases**: Application data, configuration files
   - **Requirements**: Reliable, cost-effective
   - **Backup**: Regular snapshots

3. **Archive Storage (Low Cost)**
   - **Type**: Archive storage
   - **Use Cases**: Long-term backups, audit logs
   - **Requirements**: Low cost, high durability
   - **Backup**: Multi-region replication

### Data Management

```yaml
# Storage classes for different use cases
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/minikube-hostpath
parameters:
  type: pd-ssd
  replication-type: regional-pd

---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: kubernetes.io/minikube-hostpath
parameters:
  type: pd-standard

---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: archive
provisioner: kubernetes.io/minikube-hostpath
parameters:
  type: pd-standard
  replication-type: regional-pd
```

## Security Architecture

### Multi-Layer Security Model

```
┌─────────────────────────────────────────────────────────┐
│                Security Architecture                    │
│                                                         │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              Perimeter Security                     │ │
│  │  • WAF (Web Application Firewall)                  │ │
│  │  • DDoS Protection                                 │ │
│  │  • SSL/TLS Termination                             │ │
│  │  • Rate Limiting                                   │ │
│  └─────────────────────────────────────────────────────┘ │
│                         │                               │
│                         ▼                               │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              Network Security                       │ │
│  │  • Network Policies                                │ │
│  │  • Service Mesh (Optional)                         │ │
│  │  • VPN/Private Networks                            │ │
│  │  • Network Segmentation                            │ │
│  └─────────────────────────────────────────────────────┘ │
│                         │                               │
│                         ▼                               │
│  ┌─────────────────────────────────────────────────────┐ │
│  │            Identity & Access Management             │ │
│  │  • OAuth 2.0 / OpenID Connect                      │ │
│  │  • RBAC (Role-Based Access Control)                │ │
│  │  • JWT Token Validation                            │ │
│  │  • Multi-Factor Authentication                     │ │
│  └─────────────────────────────────────────────────────┘ │
│                         │                               │
│                         ▼                               │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              Application Security                   │ │
│  │  • Input Validation                                │ │
│  │  • SQL Injection Prevention                        │ │
│  │  • XSS Protection                                  │ │
│  │  • CSRF Protection                                 │ │
│  └─────────────────────────────────────────────────────┘ │
│                         │                               │
│                         ▼                               │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                Data Security                        │ │
│  │  • Encryption at Rest                              │ │
│  │  • Encryption in Transit                           │ │
│  │  • Key Management                                  │ │
│  │  • Data Classification                             │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Authentication Flow

```
┌─────────────┐                 ┌─────────────┐
│    User     │   1. Login      │   Portal    │
│             │────────────────►│  Frontend   │
└─────────────┘                 └─────────────┘
       ▲                               │
       │                               │ 2. Redirect to
       │                               │    Keycloak
       │                               ▼
       │                        ┌─────────────┐
       │ 6. Access with         │  Keycloak   │
       │    JWT Token           │     IAM     │
       │                        └─────────────┘
       │                               │
       │                               │ 3. Authenticate
       │                               │    User
       │                               ▼
       │                        ┌─────────────┐
       │                        │    User     │
       │ 5. JWT Token           │ Credentials │
       │                        │ Validation  │
       │                        └─────────────┘
       │                               │
       │                               │ 4. Generate
       │                               │    JWT Token
       └───────────────────────────────┘
```

**Authentication Steps:**
1. User initiates login via Portal frontend
2. Portal redirects to Keycloak for authentication
3. Keycloak validates user credentials
4. Keycloak generates JWT token with user claims
5. JWT token returned to user via Portal
6. User accesses protected resources with JWT token

### Authorization Matrix

| Role | Portal Access | EDC Management | ArgoCD Access | Monitoring Access |
|------|--------------|----------------|---------------|------------------|
| **Admin** | Full | Full | Full | Full |
| **Developer** | Read/Write | Read | Application View | Read |
| **Operator** | Read | Read/Write | Read | Read/Write |
| **Viewer** | Read | Read | None | Read |
| **Service Account** | API Only | API Only | Sync Only | Metrics Only |

## Performance Characteristics

### Expected Performance Metrics

| Component | Metric | Target | Measurement Window |
|-----------|--------|--------|-------------------|
| **Portal Frontend** | Page Load Time | < 3 seconds | Initial load |
| **Portal API** | Response Time | < 500ms (95th percentile) | Per request |
| **EDC Control Plane** | Contract Negotiation | < 30 seconds | End-to-end |
| **EDC Data Plane** | Data Transfer Rate | > 100 MB/s | Per transfer |
| **Database** | Query Response | < 100ms (95th percentile) | Per query |
| **Prometheus** | Query Response | < 5 seconds | Dashboard load |
| **Grafana** | Dashboard Load | < 3 seconds | Initial render |
| **ArgoCD** | Sync Time | < 2 minutes | Per application |

### Scalability Targets

| Component | Current Scale | Target Scale | Scaling Method |
|-----------|--------------|--------------|----------------|
| **Portal Users** | 100 concurrent | 1000 concurrent | Horizontal |
| **EDC Connectors** | 2 instances | 10+ instances | Horizontal |
| **Data Transfers** | 10 concurrent | 100 concurrent | Horizontal |
| **Metrics Storage** | 30 days | 90 days | Vertical |
| **Log Storage** | 7 days | 30 days | Vertical |
| **Database** | 10GB | 100GB | Vertical |

### Performance Optimization

```yaml
# Example HPA for automatic scaling
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: portal-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: portal-backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## Technology Stack

### Core Technologies

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| **Container Orchestration** | Kubernetes | 1.28+ | Container management |
| **Package Management** | Helm | 3.x | Application packaging |
| **Infrastructure Provisioning** | Terraform | 1.0+ | Infrastructure as Code |
| **GitOps** | ArgoCD | 2.8+ | Continuous deployment |
| **Service Mesh** | Istio | 1.18+ | Service communication (optional) |
| **Ingress** | Nginx Ingress | 1.8+ | Traffic routing |

### Application Technologies

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| **Portal Frontend** | React | 18.x | User interface |
| **Portal Backend** | Spring Boot | 3.x | API server |
| **EDC Connector** | Eclipse EDC | Latest | Data space connector |
| **IAM** | Keycloak | 22.x | Identity management |
| **Database** | PostgreSQL | 15.x | Primary data store |
| **Cache** | Redis | 7.x | Session and data cache |
| **Message Queue** | Apache Kafka | 3.x | Event streaming (optional) |

### Observability Technologies

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| **Metrics** | Prometheus | 2.45+ | Metrics collection |
| **Visualization** | Grafana | 10.x | Dashboard and visualization |
| **Logging** | Loki | 2.9+ | Log aggregation |
| **Log Collection** | Promtail | 2.9+ | Log shipping |
| **Alerting** | Alertmanager | 0.26+ | Alert management |
| **Tracing** | Jaeger | 1.47+ | Distributed tracing (optional) |

### Development and Testing

| Category | Technology | Version | Purpose |
|----------|------------|---------|---------|
| **Testing Framework** | Pytest | 7.x+ | Integration testing |
| **Load Testing** | Locust | 2.x+ | Performance testing |
| **Security Scanning** | Trivy | Latest | Vulnerability scanning |
| **Code Quality** | SonarQube | 9.x+ | Code analysis (optional) |
| **API Testing** | Postman/Newman | Latest | API testing |

## High Availability and Disaster Recovery

### High Availability Design

```
Multi-Zone Deployment:
┌─────────────────────────────────────────────────────────┐
│                Production Cluster                       │
│                                                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐    │
│  │   Zone A    │ │   Zone B    │ │     Zone C      │    │
│  │             │ │             │ │                 │    │
│  │ ┌─────────┐ │ │ ┌─────────┐ │ │ ┌─────────────┐ │    │
│  │ │Master-1 │ │ │ │Master-2 │ │ │ │  Master-3   │ │    │
│  │ └─────────┘ │ │ └─────────┘ │ │ └─────────────┘ │    │
│  │ ┌─────────┐ │ │ ┌─────────┐ │ │ ┌─────────────┐ │    │
│  │ │Worker-1 │ │ │ │Worker-2 │ │ │ │  Worker-3   │ │    │
│  │ └─────────┘ │ │ └─────────┘ │ │ └─────────────┘ │    │
│  │ ┌─────────┐ │ │ ┌─────────┐ │ │ ┌─────────────┐ │    │
│  │ │Worker-4 │ │ │ │Worker-5 │ │ │ │  Worker-6   │ │    │
│  │ └─────────┘ │ │ └─────────┘ │ │ └─────────────┘ │    │
│  └─────────────┘ └─────────────┘ └─────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

**HA Components:**
- **Control Plane**: 3 master nodes across availability zones
- **Worker Nodes**: Distributed across zones with anti-affinity rules
- **Database**: PostgreSQL with read replicas and automatic failover
- **Load Balancers**: Multi-zone load balancing with health checks
- **Storage**: Replicated storage across zones

### Disaster Recovery Strategy

| RTO (Recovery Time Objective) | RPO (Recovery Point Objective) | Strategy |
|-------------------------------|--------------------------------|----------|
| **Critical Services**: 1 hour | **Database**: 15 minutes | Hot standby in secondary region |
| **Non-Critical Services**: 4 hours | **Configuration**: Real-time | GitOps-based recovery |
| **Full System**: 8 hours | **Logs**: 5 minutes | Cross-region backup |

## Future Considerations

### Roadmap Items

1. **Service Mesh Integration**
   - **Technology**: Istio or Linkerd
   - **Benefits**: Advanced traffic management, security policies
   - **Timeline**: 6 months

2. **Multi-Cluster Federation**
   - **Technology**: Cluster API, Admiral
   - **Benefits**: Geographic distribution, improved resilience
   - **Timeline**: 12 months

3. **AI/ML Integration**
   - **Technology**: Kubeflow, MLOps pipelines
   - **Benefits**: Intelligent monitoring, predictive analytics
   - **Timeline**: 18 months

4. **Enhanced Security**
   - **Technology**: OPA Gatekeeper, Falco
   - **Benefits**: Policy as code, runtime security
   - **Timeline**: 9 months

### Migration Paths

1. **Cloud Migration**
   - **From**: Minikube local deployment
   - **To**: Managed Kubernetes (EKS, GKE, AKS)
   - **Strategy**: Blue-green deployment with DNS cutover

2. **Multi-Region Deployment**
   - **Current**: Single region deployment
   - **Target**: Multi-region with data replication
   - **Strategy**: Gradual expansion with cross-region networking

3. **Hybrid Cloud Integration**
   - **Current**: Single cloud provider
   - **Target**: Multi-cloud with workload distribution
   - **Strategy**: Federated clusters with unified management

### Emerging Technologies

1. **WebAssembly (WASM)**
   - **Use Case**: Edge computing, plugin architecture
   - **Integration**: WASM runtime in data plane

2. **Kubernetes Operators**
   - **Use Case**: Application lifecycle management
   - **Development**: Custom operators for Tractus-X components

3. **GitOps 2.0**
   - **Features**: Progressive delivery, automated rollbacks
   - **Tools**: Argo Rollouts, Flagger

4. **eBPF-based Networking**
   - **Use Case**: Advanced networking and observability
   - **Implementation**: Cilium for CNI and security

---

This architecture documentation should be updated as the system evolves and new components are added or existing ones are modified. Regular architecture reviews should be conducted to ensure the design continues to meet business requirements and technical constraints.