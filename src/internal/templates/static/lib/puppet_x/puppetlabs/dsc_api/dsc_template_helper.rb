require 'pathname'

module PuppetX
module DscApi
class TemplateHelpers

  def should_to_resource(should, context, dsc_invoke_method)
    resource = {}
    resource[:parameters] = {}
    [:name, :dscmeta_resource_friendly_name, :dscmeta_resource_name, :dscmeta_module_name].each do |k|
      resource[k] = context.type.definition[k]
    end
    should.each do |k,v|
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

  def self.ps_script_content(resource, template_content)
    @param_hash       = resource
    template          = ERB.new(template_content, nil, '-')
    template.result(binding)
  end

  def self.format_dsc_value(dsc_value)
    case
    when dsc_value.class.name == 'String'
      "'#{escape_quotes(dsc_value)}'"
    when dsc_value.class.ancestors.include?(Numeric)
      "#{dsc_value}"
    when [:true, :false].include?(dsc_value)
      "$#{dsc_value.to_s}"
    when ['trueclass','falseclass'].include?(dsc_value.class.name.downcase)
      "$#{dsc_value.to_s}"
    when dsc_value.class.name == 'Array'
      "@(" + dsc_value.collect{|m| format_dsc_value(m)}.join(', ') + ")"
    when dsc_value.class.name == 'Hash'
      "@{" + dsc_value.collect{|k, v| format_dsc_value(k) + ' = ' + format_dsc_value(v)}.join('; ') + "}"
    when dsc_value.class.name == 'Puppet::Pops::Types::PSensitiveType::Sensitive'
      "'#{escape_quotes(dsc_value.unwrap)}'"
    else
      fail "unsupported type #{dsc_value.class} of value '#{dsc_value}'"
    end
  end

  def self.format_pscredential(dsc_value, mof_type)
    "[PSCustomObject]#{format_dsc_value(dsc_value)} | new-pscredential"
  end

  def self.format_cim_instance(dsc_value, mof_type)
    vals = dsc_value.is_a?(Hash) ? dsc_value : [dsc_value]
    vals = vals.collect do |vs|
      "(New-CimInstance -ClassName '#{mof_type.gsub('[]','')}' -ClientOnly -Property #{format_dsc_value(vs)})"
    end
    # Ensure that we pass a single CimInstance or array correctly based on MOF schema definition
    if dsc_value.is_a?(Hash)
      value = "[CimInstance]#{vals.first}"
    else
      value = "[CimInstance[]]@(#{vals.join(',')})"
    end
    value
  end

  def self.escape_quotes(text)
    text.gsub("'", "''")
  end
end
end
end
