FROM ubuntu:latest
RUN apt update -y
RUN apt install ca-certificates curl git direnv -y
RUN echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

# Install Nix
RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux \
  --extra-conf "sandbox = false" \
  --init none \
  --no-confirm
ENV PATH="${PATH}:/nix/var/nix/profiles/default/bin"

CMD ["sleep", "infinity"]