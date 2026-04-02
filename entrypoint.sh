#!/bin/bash
set -e

# --- Configuration ---
ROOT_USER=${ROOT_USER:-root}
SSH_USER=${SSH_USER:-openssh}

# --- 1. Create Users ---
# Create SSH user if not exists (Always create, regardless of password settings)
if ! id -u "$SSH_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo "$SSH_USER"
    echo "Created user: $SSH_USER"
fi

# Ensure home directory permissions are correct (fixes issues with mounted volumes)
chown -R "$SSH_USER:$SSH_USER" "/home/$SSH_USER"

# --- 2. Handle Passwords ---
# We do not 'useradd' root because it already exists.
PASS_AUTH="no"

if [ "$DISABLE_PASSWORD" != "true" ]; then
    # Handle Root Password
    if [ -n "$ROOT_PASSWORD_FILE" ] && [ -f "$ROOT_PASSWORD_FILE" ]; then
        echo "root:$(cat $ROOT_PASSWORD_FILE)" | chpasswd
        PASS_AUTH="yes"
    elif [ -n "$ROOT_PASSWORD" ]; then
        echo "root:$ROOT_PASSWORD" | chpasswd
        PASS_AUTH="yes"
    fi

    # Handle SSH User Password
    if [ -n "$SSH_PASSWORD_FILE" ] && [ -f "$SSH_PASSWORD_FILE" ]; then
        echo "$SSH_USER:$(cat $SSH_PASSWORD_FILE)" | chpasswd
        PASS_AUTH="yes"
    elif [ -n "$SSH_PASSWORD" ]; then
        echo "$SSH_USER:$SSH_PASSWORD" | chpasswd
        PASS_AUTH="yes"
    fi
fi

# --- 3. Handle SSH Keys ---
mkdir -p /home/$SSH_USER/.ssh
chmod 700 /home/$SSH_USER/.ssh

if [ "$DISABLE_KEY" != "true" ]; then
    if [ -n "$SSH_PUBKEY_FILE" ] && [ -f "$SSH_PUBKEY_FILE" ]; then
        cat "$SSH_PUBKEY_FILE" > /home/$SSH_USER/.ssh/authorized_keys
    elif [ -n "$SSH_PUBKEY" ]; then
        echo "$SSH_PUBKEY" > /home/$SSH_USER/.ssh/authorized_keys
    else
        # Generate keys if none provided (idempotent check inside gen_ssh_keys.sh)
        /usr/local/bin/gen_ssh_keys.sh "$SSH_USER" /keys
        
        # Note: We copy the PUBLIC key to authorized_keys.
        # The private key remains in /keys for the admin to retrieve.
        if [ -f "/keys/$SSH_USER.pub" ]; then
            cat "/keys/$SSH_USER.pub" > /home/$SSH_USER/.ssh/authorized_keys
        fi
    fi
    
    chmod 600 /home/$SSH_USER/.ssh/authorized_keys
    chown -R "$SSH_USER:$SSH_USER" /home/$SSH_USER/.ssh
fi

# --- 4. Harden SSH Configuration ---
mkdir -p /etc/ssh/sshd_config.d

# Set PasswordAuthentication based on whether a password was actually set
echo "PasswordAuthentication $PASS_AUTH" > /etc/ssh/sshd_config.d/hardening.conf
echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config.d/hardening.conf
echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config.d/hardening.conf

# --- 5. Start Services ---
# Generate host keys if missing
ssh-keygen -A

echo "Starting SSH daemon..."
exec /usr/sbin/sshd -D -e
