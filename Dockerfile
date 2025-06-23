FROM aztecprotocol/sysbox:3.0

# Install system packages
RUN apt-get install -y --no-install-recommends \
    bash-completion \
    less \
    inotify-tools \
    fzf \
    btop \
    lsof \
    apt-transport-https \
    ca-certificates gnupg \
    curl

# Install Google Cloud SDK
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && apt-get update -y && apt-get install google-cloud-cli -y && \
    apt update && \
    apt install -y --no-install-recommends \
      kubectl \
      google-cloud-cli \
      google-cloud-cli-gke-gcloud-auth-plugin \
      || true

# Configure SSH
RUN mkdir -p /etc/systemd/system/ssh.socket.d && \
    echo "[Socket]" > /etc/systemd/system/ssh.socket.d/override.conf && \
    echo "ListenStream=" >> /etc/systemd/system/ssh.socket.d/override.conf && \
    echo "ListenStream=2222" >> /etc/systemd/system/ssh.socket.d/override.conf && \
    echo "StreamLocalBindUnlink yes" > /etc/ssh/sshd_config.d/gpg-agent.conf

# Setup Rust environment
ENV CARGO_HOME=/opt/rust/cargo
RUN chown -R ubuntu:ubuntu /opt/rust
RUN rustup install stable && rustup default stable
RUN curl -L https://foundry.paradigm.xyz | bash

# Install Rust CLI tools
RUN cargo --locked install \
    zoxide \
    ripgrep \
    bat \
    eza \
    starship

# Install Node.js tools
RUN npm install -g eslint_d

# Switch to ubuntu user
USER ubuntu

# Copy configuration files
COPY .bashrc_extra $HOME/.bashrc_extra
COPY awsmfa $HOME/.local/bin/awsmfa

# Setup npm global directory
RUN mkdir -p $HOME/.npm-global && \
    npm config set prefix '$HOME/.npm-global'

# Setup user configuration
RUN mkdir -p $HOME/.config/git $HOME/.config/tmux $HOME/.ssh && \
    curl -o $HOME/.ssh/authorized_keys  https://github.com/alexghr.keys && \
    curl -o $HOME/.config/git/config https://raw.githubusercontent.com/alexghr/nix/refactor/flake.parts/hosts/palpatine/ag/config/gitconfig && \
    curl -o $HOME/.config/tmux/tmux.conf https://raw.githubusercontent.com/alexghr/nix/refactor/flake.parts/hosts/palpatine/ag/config/tmux.conf

# Add bashrc_extra to bashrc
RUN echo 'source $HOME/.bashrc_extra' >> $HOME/.bashrc

# Setup workspace
WORKDIR /workspaces
RUN rustup override set 1.75

# Switch back to root for system configuration
USER root

# Install Neovim (architecture-specific)
WORKDIR /tmp
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ]; then \
        curl -LO https://github.com/neovim/neovim/releases/download/v0.10.4/nvim-linux-arm64.tar.gz && \
        mkdir -p /usr/local && \
        tar xzvf nvim-linux-arm64.tar.gz -C /usr/local --strip-components 1 && \
        rm nvim-linux-arm64.tar.gz; \
    else \
        curl -LO https://github.com/neovim/neovim/releases/download/v0.10.4/nvim-linux-x86_64.tar.gz && \
        mkdir -p /usr/local && \
        tar xzvf nvim-linux-x86_64.tar.gz -C /usr/local --strip-components 1 && \
        rm nvim-linux-x86_64.tar.gz; \
    fi

# Install act
WORKDIR /usr/local
RUN curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Copy etc directory
COPY ./etc /

WORKDIR /root