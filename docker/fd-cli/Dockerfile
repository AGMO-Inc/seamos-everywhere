# syntax=docker/dockerfile:1
# fd-cli image — refresh ONLY the FeatureDesigner GUI distro under /opt/nevonex/.
# Inherits all baked-in apt deps, Xvfb/x11vnc/noVNC, mosquitto, INSTALL_x86_64.tar.xz
# under configuration/.cp/dependencies/, and /opt/fd-cli/reference/* from upstream
# fd-cli:stable. The runtime helper scripts (entrypoint.sh, fd-commands.sh, etc.)
# are bind-mounted from skills/run-app/fd-cli-runtime/ at run time, so we don't
# touch /opt/fd-cli/scripts/ here.
FROM --platform=linux/amd64 public.ecr.aws/g0j5z0m9/fd-cli:stable

# Wipe the old GUI distro (timestamp 202602121119~202602121353) and drop in the
# new one (202604210641~202604210647). ADD auto-extracts the tar.gz into the
# target directory.
RUN rm -rf /opt/nevonex && mkdir -p /opt/nevonex
ADD ref/FD/FeatureDesigner-linux.gtk.x86_64-8.6.0-SNAPSHOT-260421.1217.tar.gz /opt/nevonex/
RUN chmod +x /opt/nevonex/FeatureDesigner

# Eclipse OSGi configuration cache is keyed to the previous plugin set; leaving
# it in place causes FeatureDesigner to fail to resolve the new bundles on first
# launch. FeatureDesigner regenerates it from configuration/config.ini on next
# start. Keep configuration/config.ini itself (it ships in the tarball).
RUN rm -rf /opt/nevonex/configuration/org.eclipse.osgi

# Pre-extract the Platform Service runtime archive that fd-commands.sh expects
# at *first* container launch. Baseline :stable shipped this at
# /opt/nevonex/configuration/org.eclipse.osgi/<bundleId>/0/.cp/dependencies/INSTALL_x86_64.tar.xz
# because FeatureDesigner had been launched once during upstream image build,
# extracting the archive from inside com.bosch.fsp.cpp.codegen_*.jar. We do the
# same extraction up-front so the new image works without an FD warm-up step.
# fd-commands.sh locates the archive via:
#   find /opt/nevonex/configuration/org.eclipse.osgi -path '*/dependencies/INSTALL_x86_64.tar.xz'
# so any subpath that ends with /dependencies/INSTALL_x86_64.tar.xz matches.
RUN set -eux; \
    deps_jar=$(ls /opt/nevonex/plugins/com.bosch.fsp.cpp.codegen_*.jar | grep -v '\.ui_' | head -1); \
    target=/opt/nevonex/configuration/org.eclipse.osgi/.prebake/0/.cp/dependencies; \
    mkdir -p "$target"; \
    (cd "$target/.." && jar xf "$deps_jar" dependencies/INSTALL_x86_64.tar.xz); \
    test -s "$target/INSTALL_x86_64.tar.xz"
