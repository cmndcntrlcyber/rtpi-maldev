graph TD
    subgraph "User Access"
        Client[Client Browser]
    end

    subgraph "Reverse Proxy"
        Nginx[Nginx Reverse Proxy]
    end

    subgraph "Source Control"
        Gitea[Gitea Git Server]
    end

    subgraph "CI/CD Pipeline"
        DroneServer[Drone Server]
        DroneRunner[Drone Runner]
    end

    subgraph "Container Management"
        Portainer[Portainer CE]
    end

    subgraph "Virtual Workspaces"
        KasmManager[Kasm Manager]
        KasmAgent[Kasm Agent]
        KasmPostman[Kasm Postman]
        DevOpsEnv[DevOps Environment]
    end

    subgraph "Database Layer"
        PostgreSQL[PostgreSQL]
        Redis[Redis]
    end

    subgraph "Integration"
        Webhook[Webhook Handler]
    end

    subgraph "Storage"
        Volumes[Docker Volumes]
    end

    %% Connections
    Client --> Nginx
    Nginx --> Gitea
    Nginx --> DroneServer
    Nginx --> Portainer
    Nginx --> KasmManager
    Nginx --> Webhook

    Gitea --> DroneServer
    DroneServer --> DroneRunner
    DroneRunner -.-> Gitea
    
    KasmManager --> PostgreSQL
    KasmManager --> Redis
    KasmAgent --> KasmManager
    KasmPostman --> KasmAgent
    DevOpsEnv --> KasmAgent
    
    Webhook -.-> DroneServer
    
    Gitea -.-> Volumes
    DroneServer -.-> Volumes
    Portainer -.-> Volumes
    KasmManager -.-> Volumes
    PostgreSQL -.-> Volumes
    Redis -.-> Volumes

    %% External connections
    DroneRunner --> Docker[Docker Socket]
    Portainer --> Docker