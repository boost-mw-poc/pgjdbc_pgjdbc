# Copyright (c) 2000-2005, JPackage Project
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the
#    distribution.
# 3. Neither the name of the JPackage Project nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


# Configuration for rpmbuild, might be specified by options
# like e.g. 'rpmbuild --define "runselftest 0"'.

# =============================================================================
# IMPORTANT NOTE: This spec file is maintained on two places -- in native
# Fedora repo [1] and in pgjdbc upstream [2].  Please, keep that in sync
# (manual effort!) so both Fedora and Upstream can benefit from automatic
# packaging CI, this is now done in Fedora Copr projects [3, 4].
# [1] https://src.fedoraproject.org/rpms/postgresql-jdbc
# [2] https://github.com/pgjdbc/pgjdbc/tree/master/packaging/rpm
# [3] https://copr.fedorainfracloud.org/coprs/g/pgjdbc/pgjdbc/
# [4] https://copr.fedorainfracloud.org/coprs/g/pgjdbc/pgjdbc-ci/
# ============================================================================

%{!?runselftest:%global runselftest 1}

%global section		devel
%global source_path	pgjdbc/src/main/java/org/postgresql

Summary:	JDBC driver for PostgreSQL
Name:		postgresql-jdbc
Version:	GENERATED
Release:	GENERATED
License:	BSD-2-Clause
URL:		http://jdbc.postgresql.org/

Source0:	https://repo1.maven.org/maven2/org/postgresql/postgresql/%{version}/postgresql-%{version}-jdbc-src.tar.gz
Provides:	pgjdbc = %version-%release

BuildArch:	noarch
ExclusiveArch:  %{java_arches} noarch
BuildRequires:	java-devel >= 1.8
BuildRequires:	maven-local
BuildRequires:	maven-bundle-plugin

BuildRequires:	mvn(com.ongres.scram:scram-client)
BuildRequires:	mvn(org.apache.maven.plugins:maven-clean-plugin)
BuildRequires:	mvn(org.apache.maven.surefire:surefire-junit-platform)
BuildRequires:	mvn(org.junit.jupiter:junit-jupiter-api)
BuildRequires:	mvn(org.junit.jupiter:junit-jupiter-engine)
BuildRequires:	mvn(org.junit.jupiter:junit-jupiter-params)

%if %runselftest
BuildRequires:	postgresql-contrib
BuildRequires:	postgresql-test-rpm-macros
%endif

# gettext is only needed if we try to update translations
#BuildRequires:	gettext

Obsoletes:	%{name}-parent-poms < 42.2.2-2

%description
PostgreSQL is an advanced Object-Relational database management
system. The postgresql-jdbc package includes the .jar files needed for
Java programs to access a PostgreSQL database.


%package javadoc
Summary:	API docs for %{name}

%description javadoc
This package contains the API Documentation for %{name}.


%prep
%setup -c -q

mv postgresql-%{version}-jdbc-src/* .

# remove any binary libs
find -type f \( -name "*.jar" -or -name "*.class" \) | xargs rm -f

# Build parent POMs in the same Maven call.
%pom_xpath_remove "pom:plugin[pom:artifactId = 'maven-shade-plugin']"

# The system-stubs-jupiter package is not (yet?) in Fedora.
%pom_xpath_remove "pom:dependency[pom:artifactId = 'system-stubs-jupiter']"

# Remove the test files depending on system-stubs-jupiter
rm src/test/java/org/postgresql/test/jdbc2/DriverTest.java \
   src/test/java/org/postgresql/util/OSUtilTest.java \
   src/test/java/org/postgresql/util/StubEnvironmentAndProperties.java \
   src/test/java/org/postgresql/jdbcurlresolver/PgPassParserTest.java \
   src/test/java/org/postgresql/jdbcurlresolver/PgServiceConfParserTest.java

# compat symlink: requested by dtardon (libreoffice), reverts part of
# 0af97ce32de877 commit.
%mvn_file org.postgresql:postgresql %{name}/postgresql %{name} postgresql

# For compat reasons, make Maven artifact available under older coordinates.
%mvn_alias org.postgresql:postgresql postgresql:postgresql


%build
# Ideally we would run "sh update-translations.sh" here, but that results
# in inserting the build timestamp into the generated messages_*.class
# files, which makes rpmdiff complain about multilib conflicts if the
# different platforms don't build in the same minute.  For now, rely on
# upstream to have updated the translations files before packaging.

# Include PostgreSQL testing methods and variables.
%if %runselftest
%postgresql_tests_init

PGTESTS_LOCALE=C.UTF-8

cat <<EOF > build.local.properties
test.url.PGHOST=localhost
test.url.PGPORT=$PGTESTS_PORT
test.url.PGDBNAME=test
user=test
password=test
privilegedUser=$PGTESTS_ADMIN
privilegedPassword=$PGTESTS_ADMINPASS
preparethreshold=5
EOF

# Start the local PG cluster.
%postgresql_tests_start
%else
# -f is equal to -Dmaven.test.skip=true
opts="-f"
%endif

%mvn_build $opts


%install
%mvn_install


%files -f .mfiles
%license LICENSE
%doc README.md


%files javadoc -f .mfiles-javadoc
%license LICENSE


%changelog
* Sun Jan 30 2022 Pavel Raiskup <praiskup@redhat.com>
- synchronized with Fedora spec

* Tue Mar 03 2020 Vladimir Sitnikov <sitnikov.vladimir@gmail.com>
- Adapted to building from the source release

* Wed Nov 29 2017 Pavel Raiskup <praiskup@redhat.com> - 9.5.git
- no changelog in this spec file (upstream git)
