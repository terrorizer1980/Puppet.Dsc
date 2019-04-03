require 'pathname'
require Pathname.new(__FILE__).dirname + '../' + 'puppet_x/puppetlabs/dsc_api/powershell_version'

Facter.add(:powershell_version) do
  setcode do
    if Puppet::Util::Platform.windows?
      version = PuppetX::PuppetLabs::DscApi::PowerShellVersion.version
      version
    end
  end
end
