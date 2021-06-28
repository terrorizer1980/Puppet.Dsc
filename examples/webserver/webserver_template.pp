# This example is an adaptation of the MSFT_xWebSite sample code found here:
# https://github.com/dsccommunity/xWebAdministration/blob/main/source/DSCResources/MSFT_xWebSite/MSFT_xWebSite.psm1

# Declare variables; these should be overwritten for sensible values
# Our acceptance tests do this: FILE REFERENCE
$source_path      = %%SOURCE_PATH%%      # 'C:/puppet/webserver/website' # Valid File path for site HTML
$destination_path = %%DESTINATION_PATH%% # 'C:\Foo'        # Valid File Path for site HTML
$website_name     = %%WEBSITE_NAME%%     # 'example_site'  # String
$site_id          = %%SITE_ID%%          # 7               # Integer

# Install the IIS role
dsc_xwindowsfeature { 'IIS':
  dsc_ensure => 'Present',
  dsc_name   => 'Web-Server',
}

# Install the ASP .NET 4.5 role
dsc_xwindowsfeature { 'AspNet45':
  dsc_ensure => 'Present',
  dsc_name   => 'Web-Asp-Net45',
}

# Stop the default website
dsc_xwebsite { 'DefaultSite':
    dsc_ensure          => 'Present',
    dsc_name            => 'Default Web Site',
    dsc_state           => 'Stopped',
    dsc_serverautostart => false,
    dsc_physicalpath    => 'C:\inetpub\wwwroot',
    require             => Dsc_xwindowsfeature['IIS'],
}

# Copy the website content
file { 'WebContent':
    ensure  => directory,
    recurse => true,
    replace => true,
    path    => $destination_path,
    source  => $source_path,
    require => Dsc_xwindowsfeature['AspNet45'],
}

# Create the new Website
dsc_xwebsite { 'NewWebsite':
    dsc_ensure          => 'Present',
    dsc_name            => $website_name,
    dsc_siteid          => $site_id,
    dsc_state           => 'Started',
    dsc_serverautostart => true,
    dsc_physicalpath    => $destination_path,
    require             => File['WebContent'],
}
