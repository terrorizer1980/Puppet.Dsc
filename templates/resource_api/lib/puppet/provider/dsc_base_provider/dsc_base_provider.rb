require 'puppet/resource_api/simple_provider'
require 'puppet_x/puppetlabs/dsc_api/dsc_template_helper'
require 'ruby-pwsh'
require 'pathname'
require 'json'

class Puppet::Provider::DscBaseProvider < Puppet::ResourceApi::SimpleProvider

  def get(context)
    context.debug('Returning pre-canned example data')
    # context.type.definition[:dsc_invoke_method] = 'get'
    # is there an exists? method instead?
    [
      {
        name: 'foo',
        ensure: 'present',
      },
      {
        name: 'bar',
        ensure: 'present',
      },
    ]
  end

  def invoke_set_method(context, name, should)
    context.notice("Ivoking Set Method for '#{name}' with #{should.inspect}")
    resource = should_to_resource(should, context, 'set')
    script_content = ps_script_content(resource)
    context.debug("Script:\n #{script_content}")

    output = ps_manager.execute(script_content)[:stdout]
    context.err('Nothing returned') if output.nil?

    data   = JSON.parse(output)
    context.debug(data)

    context.err(data['errormessage']) if !data['errormessage'].empty?
    # notify_reboot_pending if data['rebootrequired'] == true
    data
  end

  def create(context, name, should)
    context.notice("Creating '#{name}' with #{should.inspect}")
    invoke_set_method(context, name, should)
  end

  def update(context, name, should)
    context.notice("Updating '#{name}' with #{should.inspect}")
    invoke_set_method(context, name, should)
  end

  def delete(context, name)
    context.notice("Deleting '#{name}'")
    invoke_set_method(context, name, should)
  end

  def should_to_resource(should, context, dsc_invoke_method)
    resource = {}
    resource[:parameters] = {}
    [:name, :dscmeta_resource_friendly_name, :dscmeta_resource_name, :dscmeta_module_name, :dscmeta_module_version].each do |k|
      resource[k] = context.type.definition[k]
    end
    should.each do |k,v|
      next if k == :name
      next if k == :ensure
      resource[:parameters][k] = {}
      resource[:parameters][k][:value] = v
      [:mof_type, :mof_is_embedded].each do |ky|
        resource[:parameters][k][ky] = context.type.definition[:attributes][k][ky]
      end
    end
    resource[:dsc_invoke_method] = dsc_invoke_method
    resource[:vendored_modules_path] = File.expand_path(Pathname.new(__FILE__).dirname + '../../../' + 'puppet_x/dsc_resources')
    resource[:attributes] = nil
    resource
  end

  def ps_script_content(resource)
    template_path = File.expand_path('../', __FILE__)
    preamble      = File.new(template_path + "/invoke_dsc_resource_preamble.ps1.erb").read
    template      = File.new(template_path + "/invoke_dsc_resource.ps1.erb").read
    postscript    = File.new(template_path + "/invoke_dsc_resource_postscript.ps1.erb").read
    content = preamble + template + postscript
    PuppetX::DscApi::TemplateHelpers.ps_script_content(resource, content)
  end

  def ps_manager
    debug_output = Puppet::Util::Log.level == :debug
    Pwsh::Manager.instance(Pwsh::Manager.powershell_path, Pwsh::Manager.powershell_args, debug: debug_output)
  end
end
