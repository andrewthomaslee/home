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

# Auth for FlakeHub
RUN --mount=type=secret,id=FLAKEHUB_TOKEN \
    export FLAKEHUB_TOKEN=$(cat /run/secrets/FLAKEHUB_TOKEN) && \
    echo "machine flakehub.com login flakehub password ${FLAKEHUB_TOKEN}" >> ~/.netrc && \
    echo "machine api.flakehub.com login flakehub password ${FLAKEHUB_TOKEN}" >> ~/.netrc && \
    echo "machine cache.flakehub.com login flakehub password ${FLAKEHUB_TOKEN}" >> ~/.netrc
RUN echo "netrc-file = /root/.netrc" >> /etc/nix/nix.conf
RUN echo "extra-substituters = https://cache.flakehub.com" >> /etc/nix/nix.conf && \
    echo "extra-trusted-substituters = https://cache.flakehub.com https://install.determinate.systems" >> /etc/nix/nix.conf && \
    echo "extra-trusted-public-keys = cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM= cache.flakehub.com-4:Asi8qIv291s0aYLyH6IOnr5Kf6+OF14WVjkE6t3xMio= cache.flakehub.com-5:zB96CRlL7tiPtzA9/WKyPkp3A2vqxqgdgyTVNGShPDU= cache.flakehub.com-6:W4EGFwAGgBj3he7c5fNh9NkOXw0PUVaxygCVKeuvaqU= cache.flakehub.com-7:mvxJ2DZVHn/kRxlIaxYNMuDG1OvMckZu32um1TadOR8= cache.flakehub.com-8:moO+OVS0mnTjBTcOUh2kYLQEd59ExzyoW1QgQ8XAARQ= cache.flakehub.com-9:wChaSeTI6TeCuV/Sg2513ZIM9i0qJaYsF+lZCXg0J6o= cache.flakehub.com-10:2GqeNlIp6AKp4EF2MVbE1kBOp9iBSyo0UPR9KoR0o1Y=" >> /etc/nix/nix.conf

CMD ["sleep", "infinity"]