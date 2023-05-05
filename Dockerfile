# Karellen GitHub Actions container for Sysbox

FROM ubuntu:jammy

ARG RUNNER_VERSION
ARG RUNNER_ARCH
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.3.1


RUN mkdir -p /home/runner
WORKDIR /home/runner
ENV DEBIAN_FRONTEND=noninteractive

#
# Systemd installation
#
RUN apt-get update &&                            \
    apt-get install -y --no-install-recommends   \
            systemd                              \
            systemd-sysv                         \
            libsystemd0                          \
            ca-certificates                      \
            dbus                                 \
            iptables                             \
            iproute2                             \
            kmod                                 \
            locales                              \
            sudo                                 \
            curl                                 \
            apt-utils                            \
            unzip                                \
            python3                              \
            python3-pip                          \
            udev &&                              \
                                                 \
                                                                      \
    # Install Docker                                                  \
    curl -fsSL https://get.docker.com -o get-docker.sh &&             \
    sh get-docker.sh &&                                               \
    rm get-docker.sh &&                                               \
                                                                      \
    curl -f -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz                                        \
    && rm runner.tar.gz &&                                            \
                                                                      \
    curl -f -L -o runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-docker-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip ./runner-container-hooks.zip -d ./docker                 \
    && rm runner-container-hooks.zip &&                               \
                                                                      \
    ./bin/installdependencies.sh &&                                   \
                                                                      \
    # Housekeeping                                                    \
    apt-get clean -y &&                                               \
    rm -rf                                                            \
       /var/cache/debconf/*                                           \
       /var/lib/apt/lists/*                                           \
       /var/log/*                                                     \
       /tmp/*                                                         \
       /var/tmp/*                                                     \
       /usr/share/doc/*                                               \
       /usr/share/man/*                                               \
       /usr/share/local/*

# Disable systemd services/units that are unnecessary within a container.
RUN systemctl mask systemd-udevd.service \
                   systemd-udevd-kernel.socket \
                   systemd-udevd-control.socket \
                   systemd-modules-load.service \
                   sys-kernel-debug.mount \
                   sys-kernel-tracing.mount

# Make use of stopsignal (instead of sigterm) to stop systemd containers.
STOPSIGNAL SIGRTMIN+3

# Prevents journald from reading kernel messages from /dev/kmsg
RUN echo -e "ReadKMsg=no\nForwardToConsole=yes\nStorage=none" >> /etc/systemd/journald.conf

RUN adduser --disabled-password --gecos "" --uid 1001 runner \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers \
    && echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers \
    && chown -R runner:runner /home/runner

# Disable root account
RUN passwd root -ld

ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1

COPY karellen-gha-runner-configure.service /lib/systemd/system
COPY karellen-gha-runner.service /lib/systemd/system
RUN systemctl enable karellen-gha-runner-configure karellen-gha-runner

# Set systemd as entrypoint.
ENTRYPOINT [ "/sbin/init", "--log-level=warning" ]
