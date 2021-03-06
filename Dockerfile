# default args for x86_64
ARG ARCH_SRC_DIR=x86_64
ARG ARCH_ALPINE_IMG=alpine:3.6
ARG LIZARDFS_VERSION=v3.11.3

# pull the crossbuild files image
FROM monsonnl/qemu-wrap-build-files:latest AS arch_src

# build lizardfs and stage for final image
ARG ARCH_ALPINE_IMG
FROM ${ARCH_ALPINE_IMG} AS build

COPY run.sh /BUILDSTAGE/run.sh

ARG ARCH_SRC_DIR
COPY --from=arch_src /cross-build/${ARCH_SRC_DIR}/bin/ /bin/

RUN [ "cross-build-start" ]

RUN apk update
RUN apk add gcc g++ cmake git fuse fuse-dev boost-dev make autoconf asciidoc
RUN git clone https://github.com/lizardfs/lizardfs.git

ARG LIZARDFS_VERSION
WORKDIR lizardfs
RUN git checkout ${LIZARDFS_VERSION}
RUN LIZARDFS_OFFICIAL_BUILD=NO ./configure
RUN make
RUN make install DESTDIR=/BUILDSTAGE/

WORKDIR /BUILDSTAGE
RUN cp /BUILDSTAGE/etc/mfs/mfsexports.cfg.dist /BUILDSTAGE/etc/mfs/mfsexports.cfg
RUN cp /BUILDSTAGE/var/lib/mfs/metadata.mfs.empty /BUILDSTAGE/etc/mfs/
RUN echo "PERSONALITY = master" >> /BUILDSTAGE/etc/mfs/mfsmaster.cfg && \
    echo "WORKING_USER = root"  >> /BUILDSTAGE/etc/mfs/mfsmaster.cfg && \
    echo "WORKING_GROUP = root" >> /BUILDSTAGE/etc/mfs/mfsmaster.cfg && \
    echo "AUTO_RECOVERY = 1"    >> /BUILDSTAGE/etc/mfs/mfsmaster.cfg && \
    echo "EXPORTS_FILENAME = /etc/mfs/mfsexports.cfg" >> /BUILDSTAGE/etc/mfs/mfsmaster.cfg && \
    echo "LABEL = _"              >> /BUILDSTAGE/etc/mfs/mfsmaster.cfg && \
    echo "WORKING_USER = root"    >> /BUILDSTAGE/etc/mfs/mfsmaster.cfg && \
    echo "WORKING_GROUP = root"   >> /BUILDSTAGE/etc/mfs/mfsmaster.cfg && \
    echo "ENABLE_LOAD_FACTOR = 1" >> /BUILDSTAGE/etc/mfs/mfsmaster.cfg && \
    echo "PERFORM_FSYNC = 0"      >> /BUILDSTAGE/etc/mfs/mfsmaster.cfg && \
    echo "LABEL = _ "              >> /BUILDSTAGE/etc/mfs/mfschunkserver.cfg && \
    echo "WORKING_USER = root "    >> /BUILDSTAGE/etc/mfs/mfschunkserver.cfg && \
    echo "WORKING_GROUP = root "   >> /BUILDSTAGE/etc/mfs/mfschunkserver.cfg && \
    echo "ENABLE_LOAD_FACTOR = 1 " >> /BUILDSTAGE/etc/mfs/mfschunkserver.cfg && \
    echo "PERFORM_FSYNC = 0 "      >> /BUILDSTAGE/etc/mfs/mfschunkserver.cfg && \
    echo "WORKING_USER = root "  >> /BUILDSTAGE/etc/mfs/mfsmetalogger.cfg && \
    echo "WORKING_GROUP = root " >> /BUILDSTAGE/etc/mfs/mfsmetalogger.cfg

RUN apk add --no-cache --root /BUILDSTAGE/ fuse findutils libgcc libstdc++

RUN [ "cross-build-end" ]

# build the final image
ARG ARCH_ALPINE_IMG
FROM ${ARCH_ALPINE_IMG}
MAINTAINER Nathaniel Monson <monsonnl@gmail.com>

COPY --from=build /BUILDSTAGE/ /

EXPOSE 9422

#CMD [ "/run.sh" ]
