%{!?ruby_sitelibdir: %define ruby_sitelibdir %(ruby -rrbconfig -e 'puts Object.const_get(defined?(RbConfig) ? :RbConfig : :Config)::CONFIG["sitelibdir"]')}

%global _ver 1.0.0

Name:		hiera
Version:	1.0.0
#Release:	1%{?dist}
Release:	0.1rc2%{?dist}
Summary:	A simple pluggable Hierarchical Database.

Group: 		System Environment/Base
License: 	Apache 2.0
URL:		http://projects.puppetlabs.com/projects/%{name}/
#Source0:	http://downloads.puppetlabs.com/%{name}/%{name}-%{version}.tar.gz
Source0:	http://downloads.puppetlabs.com/%{name}/%{name}-%{version}rc2.tar.gz
BuildRoot: 	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:	noarch
BuildRequires:	ruby >= 1.8.5
Requires:	ruby(abi) >= 1.8	
Requires:	ruby >= 1.8.5	

%description
A simple pluggable Hierarchical Database.

%package puppet
Summary:        A simple pluggable Hierarchical Database.
Group:          System Environment/Base
Requires:       hiera-puppet = %{version}-%{release}
Requires:       puppet
%description puppet
Functions to call hiera from within puppet.

%prep
#%setup -q  -n %{name}-%{version}
%setup -q  -n %{name}-%{version}rc2


%build


%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/%{ruby_sitelibdir}
mkdir -p $RPM_BUILD_ROOT/%{_bindir}
cp -pr lib/hiera $RPM_BUILD_ROOT/%{ruby_sitelibdir} 
cp -pr lib/hiera.rb $RPM_BUILD_ROOT/%{ruby_sitelibdir} 
cp -pr lib/puppet $RPM_BUILD_ROOT/%{ruby_sitelibdir}
install -p -m0755 bin/hiera $RPM_BUILD_ROOT/%{_bindir}

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%{_bindir}/hiera
%{ruby_sitelibdir}/hiera.rb
%{ruby_sitelibdir}/hiera
%doc CHANGELOG COPYING README.md

%files puppet
# Puppet hiera functions
%{ruby_sitelibdir}/puppet/parser/functions/*.rb


%changelog
* Mon May 14 2012 Matthaus Litteken <matthaus@puppetlabs.com> - 1.0.0-0.1rc2
- 1.0.0rc2 release

* Mon May 14 2012 Matthaus Litteken <matthaus@puppetlabs.com> - 1.0.0-0.1rc1
- 1.0.0rc1 release

* Thu May 03 2012 Matthaus Litteken <matthaus@puppetlabs.com> - 0.3.0.28-1
- Initial Hiera Packaging. Upstream version 0.3.0.28

