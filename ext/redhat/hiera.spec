%{!?ruby_sitelibdir: %define ruby_sitelibdir %(ruby -rrbconfig -e 'puts Object.const_get(defined?(RbConfig) ? :RbConfig : :Config)::CONFIG["sitelibdir"]')}

%global _ver 0.3.0.28

Name:		hiera
Version:	0.3.0.28
Release:	1%{?dist}
Summary:	A simple pluggable Hierarchical Database.

Group: 		System Environment/Base
License: 	Apache 2.0
URL:		http://projects.puppetlabs.com/projects/%{name}/
Source0:	http://downloads.puppetlabs.com/%{name}/%{name}-%{version}.tar.gz
BuildRoot: 	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:	noarch
BuildRequires:	ruby >= 1.8.5
Requires:	ruby(abi) >= 1.8	
Requires:	ruby >= 1.8.5	

%description
A simple pluggable Hierarchical Database.

%prep
%setup -q  -n %{name}-%{version}


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
# Puppet hiera functions
%{ruby_sitelibdir}/puppet
%doc CHANGES.txt COPYING README.md


%changelog
* Thu May 03 2012 Matthaus Litteken <matthaus@puppetlabs.com> - 0.3.0.28-1
- Initial Hiera Packaging. Upstream version 0.3.0.28

