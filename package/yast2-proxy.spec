#
# spec file for package yast2-proxy
#
# Copyright (c) 2018 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-proxy
Version:        4.1.1
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

BuildRequires:  update-desktop-files
BuildRequires:  yast2-buildtools >= 3.1.10
BuildRequires:  rubygem(rspec)
BuildRequires:  rubygem(yast-rake)

BuildRequires:  yast2
Requires:       yast2

# we split off that one
Conflicts:      yast2-network < 2.22.6

BuildArch:      noarch

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:        YaST2 - Proxy Configuration
License:        GPL-2.0-or-later
Group:          System/YaST
Url:            http://en.opensuse.org/Portal:YaST

%description 
This package contains the YaST2 component for proxy configuration.

%prep
%setup -n %{name}-%{version}

%check
rake test:unit

%build

%install
rake install DESTDIR="%{buildroot}"

%files
%defattr(-,root,root)
%{yast_clientdir}/*.rb
%{yast_libdir}/proxy
%{yast_moduledir}/*.rb
%{yast_yncludedir}/proxy
%{yast_desktopdir}/*.desktop
%{yast_scrconfdir}/*.scr
%{yast_schemadir}/autoyast/rnc/proxy.rnc
%{yast_icondir}
%license COPYING

%doc %{yast_docdir}

%changelog
