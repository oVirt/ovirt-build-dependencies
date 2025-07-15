#!/bin/bash -xe

# Package version is static and should be aligned with parent pom version that is
# used to build maven cache
PKG_VERSION="4.5.7"

# Either a branch name or a specific tag in ovirt-parent project for which
# the maven cache is built
ENGINE_VERSION="main"

# Additional dependencies, which are going to be added to engine and which need
# to be included in ovirt-build-dependencies, so proper build can pass
ADDITIONAL_DEPENDENCIES="
"

# Directory, where build artifacts will be stored, should be passed as the 1st parameter
ARTIFACTS_DIR=${1:-exported-artifacts}

# Directory of the local maven repo
LOCAL_MAVEN_REPO="$(pwd)/repository"


[ -d ${LOCAL_MAVEN_REPO} ] || mkdir -p ${LOCAL_MAVEN_REPO}
[ -d ${ARTIFACTS_DIR} ] || mkdir -p ${ARTIFACTS_DIR}
[ -d rpmbuild/SOURCES ] || mkdir -p rpmbuild/SOURCES

# The goal is to have all the dependencies to build the oVirt Java projects
# in a single source package, which can then be used to build the oVirt Java projects
# without the need to download all the dependencies from the internet.

# For now we gather the dependencies from different projects.
# In the future we want to have a parent project that will contain all the dependencies
# aligned with all the oVirt Java projects.

# Fetch ovirt-engine-api-metamodel
git clone --depth=1 --branch=master https://github.com/oVirt/ovirt-engine-api-metamodel.git
cd ovirt-engine-api-metamodel

# Mark current directory as safe for git to be able to execute git commands
git config --global --add safe.directory $(pwd)

# Prepare the release, which contain git hash of commit and current date
PKG_RELEASE="0.$(date +%04Y%02m%02d%02H%02M).git$(git rev-parse --short HEAD)"
#PKG_RELEASE="1"

# Set the location of the JDK that will be used for compilation:
export JAVA_HOME="${JAVA_HOME:=/usr/lib/jvm/java-21}"

# Build ovirt-engine-api-metamodel project to download all dependencies to the local maven repo
mvn \
    clean \
    install \
    -Dmaven.repo.local=${LOCAL_MAVEN_REPO}

# Install additional dependencies
for dep in ${ADDITIONAL_DEPENDENCIES} ; do
    mvn dependency:get -Dartifact=${dep} -Dmaven.repo.local=${LOCAL_MAVEN_REPO}
done

# Archive the fetched repository
cd ${LOCAL_MAVEN_REPO}/..

tar czf rpmbuild/SOURCES/ovirt-build-dependencies-${PKG_VERSION}.tar.gz repository

# Set version and release
sed \
    -e "s|@VERSION@|${PKG_VERSION}|g" \
    -e "s|@RELEASE@|${PKG_RELEASE}|g" \
    < ovirt-build-dependencies.spec.in \
    > ovirt-build-dependencies.spec

# Build source package
rpmbuild \
    -D "_topdir rpmbuild" \
    -bs ovirt-build-dependencies.spec
