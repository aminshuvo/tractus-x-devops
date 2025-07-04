#!/bin/bash
# scripts/install-tools.sh - Install all required tools for Tractus-X DevOps

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            echo "ubuntu"
        elif command -v yum >/dev/null 2>&1; then
            echo "rhel"
        elif command -v pacman >/dev/null 2>&1; then
            echo "arch"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
log_info "Detected OS: $OS"

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Docker
install_docker() {
    if command_exists docker; then
        log_success "Docker is already installed: $(docker --version)"
        return 0
    fi
    
    log_info "Installing Docker..."
    
    case $OS in
        ubuntu)
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker $USER
            rm get-docker.sh
            ;;
        macos)
            log_info "Please install Docker Desktop from: https://docs.docker.com/desktop/mac/install/"
            log_warning "Manual installation required for macOS"
            return 1
            ;;
        *)
            log_error "Unsupported OS for Docker installation"
            return 1
            ;;
    esac
    
    log_success "Docker installed successfully"
}

# Install kubectl
install_kubectl() {
    if command_exists kubectl; then
        log_success "kubectl is already installed: $(kubectl version --client --short)"
        return 0
    fi
    
    log_info "Installing kubectl..."
    
    case $OS in
        ubuntu|linux)
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
            ;;
        macos)
            if command_exists brew; then
                brew install kubectl
            else
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
                chmod +x kubectl
                sudo mv kubectl /usr/local/bin/
            fi
            ;;
        *)
            log_error "Unsupported OS for kubectl installation"
            return 1
            ;;
    esac
    
    log_success "kubectl installed successfully"
}

# Install Helm
install_helm() {
    if command_exists helm; then
        log_success "Helm is already installed: $(helm version --short)"
        return 0
    fi
    
    log_info "Installing Helm..."
    
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    log_success "Helm installed successfully"
}

# Install Minikube
install_minikube() {
    if command_exists minikube; then
        log_success "Minikube is already installed: $(minikube version --short)"
        return 0
    fi
    
    log_info "Installing Minikube..."
    
    case $OS in
        ubuntu|linux)
            curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
            sudo install minikube-linux-amd64 /usr/local/bin/minikube
            rm minikube-linux-amd64
            ;;
        macos)
            if command_exists brew; then
                brew install minikube
            else
                curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64
                sudo install minikube-darwin-amd64 /usr/local/bin/minikube
                rm minikube-darwin-amd64
            fi
            ;;
        *)
            log_error "Unsupported OS for Minikube installation"
            return 1
            ;;
    esac
    
    log_success "Minikube installed successfully"
}

# Install Terraform
install_terraform() {
    if command_exists terraform; then
        log_success "Terraform is already installed: $(terraform --version | head -1)"
        return 0
    fi
    
    log_info "Installing Terraform..."
    
    TERRAFORM_VERSION="1.5.7"
    
    case $OS in
        ubuntu|linux)
            wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
            sudo apt update && sudo apt install terraform
            ;;
        macos)
            if command_exists brew; then
                brew tap hashicorp/tap
                brew install hashicorp/tap/terraform
            else
                curl -LO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_darwin_amd64.zip"
                unzip "terraform_${TERRAFORM_VERSION}_darwin_amd64.zip"
                sudo mv terraform /usr/local/bin/
                rm "terraform_${TERRAFORM_VERSION}_darwin_amd64.zip"
            fi
            ;;
        *)
            log_error "Unsupported OS for Terraform installation"
            return 1
            ;;
    esac
    
    log_success "Terraform installed successfully"
}

# Install jq
install_jq() {
    if command_exists jq; then
        log_success "jq is already installed: $(jq --version)"
        return 0
    fi
    
    log_info "Installing jq..."
    
    case $OS in
        ubuntu)
            sudo apt-get update && sudo apt-get install -y jq
            ;;
        rhel)
            sudo yum install -y jq
            ;;
        arch)
            sudo pacman -S jq
            ;;
        macos)
            if command_exists brew; then
                brew install jq
            else
                curl -L https://github.com/stedolan/jq/releases/latest/download/jq-osx-amd64 -o jq
                chmod +x jq
                sudo mv jq /usr/local/bin/
            fi
            ;;
        *)
            log_error "Unsupported OS for jq installation"
            return 1
            ;;
    esac
    
    log_success "jq installed successfully"
}

# Install yq
install_yq() {
    if command_exists yq; then
        log_success "yq is already installed: $(yq --version)"
        return 0
    fi
    
    log_info "Installing yq..."
    
    VERSION="v4.35.2"
    BINARY="yq_$(uname | tr '[:upper:]' '[:lower:]')_amd64"
    
    curl -L "https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}" -o yq
    chmod +x yq
    sudo mv yq /usr/local/bin/
    
    log_success "yq installed successfully"
}

# Install ArgoCD CLI
install_argocd_cli() {
    if command_exists argocd; then
        log_success "ArgoCD CLI is already installed: $(argocd version --client --short)"
        return 0
    fi
    
    log_info "Installing ArgoCD CLI..."
    
    case $OS in
        ubuntu|linux)
            curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
            chmod +x argocd-linux-amd64
            sudo mv argocd-linux-amd64 /usr/local/bin/argocd
            ;;
        macos)
            if command_exists brew; then
                brew install argocd
            else
                curl -sSL -o argocd-darwin-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-amd64
                chmod +x argocd-darwin-amd64
                sudo mv argocd-darwin-amd64 /usr/local/bin/argocd
            fi
            ;;
        *)
            log_error "Unsupported OS for ArgoCD CLI installation"
            return 1
            ;;
    esac
    
    log_success "ArgoCD CLI installed successfully"
}

# Install k6 (performance testing)
install_k6() {
    if command_exists k6; then
        log_success "k6 is already installed: $(k6 version)"
        return 0
    fi
    
    log_info "Installing k6..."
    
    case $OS in
        ubuntu)
            sudo gpg -k
            sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
            echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
            sudo apt-get update
            sudo apt-get install k6
            ;;
        macos)
            if command_exists brew; then
                brew install k6
            else
                curl -L https://github.com/grafana/k6/releases/latest/download/k6-v0.47.0-macos-amd64.zip -o k6.zip
                unzip k6.zip
                sudo mv k6-v0.47.0-macos-amd64/k6 /usr/local/bin/
                rm -rf k6.zip k6-v0.47.0-macos-amd64
            fi
            ;;
        *)
            log_error "Unsupported OS for k6 installation"
            return 1
            ;;
    esac
    
    log_success "k6 installed successfully"
}

# Install Node.js and npm (for integration tests)
install_nodejs() {
    if command_exists node && command_exists npm; then
        log_success "Node.js and npm are already installed: $(node --version), $(npm --version)"
        return 0
    fi
    
    log_info "Installing Node.js and npm..."
    
    case $OS in
        ubuntu)
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        macos)
            if command_exists brew; then
                brew install node
            else
                curl -L https://nodejs.org/dist/v18.17.1/node-v18.17.1-darwin-x64.tar.gz -o node.tar.gz
                tar -xzf node.tar.gz
                sudo mv node-v18.17.1-darwin-x64/bin/* /usr/local/bin/
                sudo mv node-v18.17.1-darwin-x64/lib/* /usr/local/lib/
                rm -rf node.tar.gz node-v18.17.1-darwin-x64
            fi
            ;;
        *)
            log_error "Unsupported OS for Node.js installation"
            return 1
            ;;
    esac
    
    log_success "Node.js and npm installed successfully"
}

# Install curl (if not present)
install_curl() {
    if command_exists curl; then
        log_success "curl is already installed"
        return 0
    fi
    
    log_info "Installing curl..."
    
    case $OS in
        ubuntu)
            sudo apt-get update && sudo apt-get install -y curl
            ;;
        rhel)
            sudo yum install -y curl
            ;;
        arch)
            sudo pacman -S curl
            ;;
        macos)
            log_info "curl should be pre-installed on macOS"
            ;;
        *)
            log_error "Unsupported OS for curl installation"
            return 1
            ;;
    esac
    
    log_success "curl installed successfully"
}

# Verify all installations
verify_installations() {
    log_info "Verifying all tool installations..."
    
    local tools=("docker" "kubectl" "helm" "minikube" "terraform" "jq" "yq" "argocd" "k6" "node" "npm" "curl")
    local failed_tools=()
    
    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            log_success "$tool: ✅"
        else
            log_error "$tool: ❌"
            failed_tools+=("$tool")
        fi
    done
    
    if [ ${#failed_tools[@]} -eq 0 ]; then
        log_success "All tools installed successfully!"
        return 0
    else
        log_error "Failed to install: ${failed_tools[*]}"
        return 1
    fi
}

# Create useful aliases
create_aliases() {
    log_info "Creating useful aliases..."
    
    local alias_file="$HOME/.tractus-x-aliases"
    
    cat > "$alias_file" << 'EOF'
# Tractus-X DevOps Aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias kga='kubectl get all'
alias kdp='kubectl describe pod'
alias kds='kubectl describe service'
alias kl='kubectl logs'
alias kpf='kubectl port-forward'
alias kctx='kubectl config current-context'

# Helm aliases
alias h='helm'
alias hls='helm list'
alias hlsa='helm list --all-namespaces'
alias hs='helm status'
alias hh='helm history'

# ArgoCD aliases
alias acd='argocd'
alias acdl='argocd login'
alias acda='argocd app'
alias acdg='argocd app get'
alias acds='argocd app sync'

# Minikube aliases
alias mk='minikube'
alias mks='minikube status'
alias mkd='minikube dashboard'
alias mkt='minikube tunnel'
alias mkip='minikube ip'

# Terraform aliases
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tfs='terraform show'

# Docker aliases
alias d='docker'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlogs='docker logs'

# Tractus-X specific
alias tx-status='kubectl get pods --all-namespaces | grep -E "(tractus-x|edc-standalone|monitoring|argocd)"'
alias tx-logs='kubectl logs -f'
alias tx-health='./scripts/health-check.sh'
alias tx-access='./access-services.sh'
EOF
    
    # Add to shell profile
    if [ -f "$HOME/.bashrc" ]; then
        echo "source $alias_file" >> "$HOME/.bashrc"
    fi
    
    if [ -f "$HOME/.zshrc" ]; then
        echo "source $alias_file" >> "$HOME/.zshrc"
    fi
    
    log_success "Aliases created in $alias_file"
    log_info "Run 'source ~/.bashrc' or 'source ~/.zshrc' to load aliases"
}

# Setup development environment
setup_dev_environment() {
    log_info "Setting up development environment..."
    
    # Create necessary directories
    mkdir -p ~/.kube
    mkdir -p ~/.config/helm
    mkdir -p ~/.minikube
    
    # Set up Git hooks (if in a git repository)
    if [ -d ".git" ]; then
        log_info "Setting up Git hooks..."
        
        cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook for Tractus-X DevOps

# Check Terraform formatting
if command -v terraform >/dev/null 2>&1; then
    terraform fmt -check -recursive terraform/ || {
        echo "Terraform files need formatting. Run: terraform fmt -recursive terraform/"
        exit 1
    }
fi

# Check YAML syntax
if command -v yamllint >/dev/null 2>&1; then
    yamllint kubernetes/ || {
        echo "YAML syntax errors found"
        exit 1
    }
fi

echo "Pre-commit checks passed!"
EOF
        
        chmod +x .git/hooks/pre-commit
        log_success "Git pre-commit hook installed"
    fi
    
    log_success "Development environment setup completed"
}

# Main installation function
main() {
    echo "🛠️  Tractus-X DevOps Tools Installation"
    echo "======================================"
    echo
    
    log_info "Starting tool installation for $OS..."
    
    # Install tools in order of dependency
    install_curl
    install_docker
    install_kubectl
    install_helm
    install_minikube
    install_terraform
    install_jq
    install_yq
    install_argocd_cli
    install_k6
    install_nodejs
    
    # Verify installations
    verify_installations
    
    # Setup environment
    create_aliases
    setup_dev_environment
    
    echo
    log_success "🎉 All tools installed successfully!"
    echo
    echo "Next steps:"
    echo "1. Start Docker Desktop (if using macOS/Windows)"
    echo "2. Run: source ~/.bashrc (or ~/.zshrc)"
    echo "3. Run: ./scripts/setup-minikube.sh"
    echo "4. Run: ./scripts/deploy-all.sh"
    echo
    echo "For troubleshooting, see: docs/TROUBLESHOOTING.md"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo
        echo "Install all required tools for Tractus-X DevOps"
        echo
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo "  --verify      Only verify existing installations"
        echo
        exit 0
        ;;
    --verify)
        verify_installations
        exit $?
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown argument: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac