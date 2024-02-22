Summary: nc_transfer - Transferring data to remote servers.
Name: nc_transfer
Version: 1.0.0
Release: 1
License: GPLv2
Source0: %{name}-%{version}.tar.gz
BuildArch: noarch
Requires: bash >= 4

%description
- nc_transfer.sh
    This script is used for transferring files from a source directory to a destination directory on a remote server using SSH and netcat.
    The script will reside in /usr/bin/

%prep
%setup -q -n %{name}-%{version}

%build
# No build actions needed for Bash scripts

%install
install -D -m 0755 nc_transfer.sh %{buildroot}%{_bindir}/nc_transfer


%files
%defattr(-,root,root,-)
%{_bindir}/nc_transfer

%changelog
* Thu Feb 22 2024 Valentin Todorov <vtodorov@ctw.travel> - 1.0.0-1
- Initial package.