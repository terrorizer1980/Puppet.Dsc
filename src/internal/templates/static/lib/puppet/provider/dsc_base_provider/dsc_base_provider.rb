require 'puppet/resource_api/simple_provider'
require 'securerandom'
require 'ruby-pwsh'
require 'pathname'
require 'json'

class Puppet::Provider::DscBaseProvider < Puppet::ResourceApi::SimpleProvider

  # Attempts to retrieve an instance of the DSC resource, invoking the `Get` method and passing any
  # namevars as the Properties to Invoke-DscResource. The result object, if any, is compared to the
  # specified properties in the Puppet Resource to decide whether it needs to be created, updated,
  # deleted, or whether it is in the desired state.
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @param names [Hash] the hash of namevar properties and their values to use to get the resource
  # @return [Hash] returns a hash representing the current state of the object, if it exists
  def get(context, names = nil)
    # Relies on the get_simple_filter feature to pass the namevars
    # as an array containing the namevar parameters as a hash.
    # This hash is functionally the same as a should hash as
    # passed to the should_to_resource method.
    context.debug('Collecting data from the DSC Resource')
    names.collect do |name|
      name = { name: name } if name.is_a? String
      invoke_get_method(context, name)
    end
  end

  # Attempts to set an instance of the DSC resource, invoking the `Set` method and thinly wrapping
  # the `invoke_set_method` method; whether this method, `update`, or `delete` is called is entirely
  # up to the Resource API based on the results
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @param name [String] the name of the resource being created
  # @return [Hash] returns a hash indicating whether or not the resource is in the desired state, whether or not it requires a reboot, and any error messages captured.
  def create(context, name, should)
    context.debug("Creating '#{name}' with #{should.inspect}")
    invoke_set_method(context, name, should)
  end

  # Attempts to set an instance of the DSC resource, invoking the `Set` method and thinly wrapping
  # the `invoke_set_method` method; whether this method, `create`, or `delete` is called is entirely
  # up to the Resource API based on the results
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @param name [String] the name of the resource being created
  # @return [Hash] returns a hash indicating whether or not the resource is in the desired state, whether or not it requires a reboot, and any error messages captured.
  def update(context, name, should)
    context.debug("Updating '#{name}' with #{should.inspect}")
    invoke_set_method(context, name, should)
  end

  # Attempts to set an instance of the DSC resource, invoking the `Set` method and thinly wrapping
  # the `invoke_set_method` method; whether this method, `create`, or `update` is called is entirely
  # up to the Resource API based on the results
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @param name [String] the name of the resource being created
  # @return [Hash] returns a hash indicating whether or not the resource is in the desired state, whether or not it requires a reboot, and any error messages captured.
  def delete(context, name)
    context.debug("Deleting '#{name}'")
    invoke_set_method(context, name, should)
  end

  # Invokes the `Get` method, passing the name_hash as the properties to use with `Invoke-DscResource`
  # The PowerShell script returns a JSON representation of the DSC Resource's CIM Instance munged as
  # best it can be for Ruby. Once that JSON is parsed into a hash this method further munges it to
  # fit the expected property definitions. Finally, it returns the object for the Resource API to
  # compare against and determine what future actions, if any, are needed.
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @param name_hash [Hash] the hash of namevars to be passed as properties to `Invoke-DscResource`
  # @return [Hash] returns a hash representing the DSC resource munged to the representation the Puppet Type expects
  def invoke_get_method(context, name_hash)
    context.debug("retrieving #{name_hash.inspect}")
    resource = should_to_resource(name_hash, context, 'get')
    script_content = ps_script_content(resource)
    context.debug("Script:\n #{redact_secrets(script_content)}")
    output = ps_manager.execute(script_content)[:stdout]
    context.err('Nothing returned') if output.nil?

    data   = JSON.parse(output)
    context.debug("raw data received: #{data.inspect}")
    context.err(data['errormessage']) if data['errormessage']
    # DSC gives back information we don't care about; filter down to only
    # those properties exposed in the type definition.
    valid_attributes = context.type.attributes.keys.collect{ |k| k.to_s }
    data.reject! { |key,value| !valid_attributes.include?("dsc_#{key.downcase}") }
    # Canonicalize the results to match the type definition representation;
    # failure to do so will prevent the resource_api from comparing the result
    # to the should hash retrieved from the resource definition in the manifest.
    data.keys.each do |key|
      type_key = "dsc_#{key.downcase}".to_sym
      data[type_key] = data.delete(key)
    end
    # If a resource is found, it's present, so refill these two Puppet-only keys
    data.merge!({ensure: 'present', name: name_hash[:name]})
    # TODO: Handle PSDscRunAsCredential flapping
    # Resources do not return the account under which they were discovered, so re-add that
    # if name_hash[:dsc_psdscrunascredential].nil?
    #   data.delete(:dsc_psdscrunascredential)
    # else
    #   data.merge!({dsc_psdscrunascredential: name_hash[:dsc_psdscrunascredential]})
    # end
    context.debug(data)
    data
  end

  # Invokes the `Set` method, passing the should hash as the properties to use with `Invoke-DscResource`
  # The PowerShell script returns a JSON hash with key-value pairs indicating whether or not the resource
  # is in the desired state, whether or not it requires a reboot, and any error messages captured.
  #
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @param should [Hash] the desired state represented definition to pass as properties to Invoke-DscResource
  # @return [Hash] returns a hash indicating whether or not the resource is in the desired state, whether or not it requires a reboot, and any error messages captured.
  def invoke_set_method(context, name, should)
    context.debug("Invoking Set Method for '#{name}' with #{should.inspect}")
    resource = should_to_resource(should, context, 'set')
    script_content = ps_script_content(resource)
    context.debug("Script:\n #{redact_secrets(script_content)}")

    output = ps_manager.execute(script_content)[:stdout]
    context.err('Nothing returned') if output.nil?

    data   = JSON.parse(output)
    context.debug(data)

    context.err(data['errormessage']) if !data['errormessage'].empty?
    # TODO: Implement this functionality for notifying a DSC reboot?
    # notify_reboot_pending if data['rebootrequired'] == true
    data
  end

  # Converts a Puppet resource hash into a hash with the information needed to call Invoke-DscResource,
  # including the desired state, the path to the PowerShell module containing the resources, the invoke
  # method, and metadata about the DSC Resource and Puppet Type.
  #
  # @param should [Hash] A hash representing the desired state of the DSC resource as defined in Puppet
  # @param context [Object] the Puppet runtime context to operate in and send feedback to
  # @param dsc_invoke_method [String] the method to pass to Invoke-DscResource: get, set, or test
  # @returns [Hash] a hash with the information needed to run `Invoke-DscResource`
  def should_to_resource(should, context, dsc_invoke_method)
    resource = {}
    resource[:parameters] = {}
    [:name, :dscmeta_resource_friendly_name, :dscmeta_resource_name, :dscmeta_module_name, :dscmeta_module_version].each do |k|
      resource[k] = context.type.definition[k]
    end
    should.each do |k,v|
      next if k == :ensure
      # PSDscRunAsCredential is considered a namevar and will always be passed, even if nil
      # To prevent flapping during runs, remove it from the resource definition unless specified
      next if  k == :dsc_psdscrunascredential && v.nil?
      resource[:parameters][k] = {}
      resource[:parameters][k][:value] = v
      [:mof_type, :mof_is_embedded].each do |ky|
        resource[:parameters][k][ky] = context.type.definition[:attributes][k][ky]
      end
    end
    resource[:dsc_invoke_method] = dsc_invoke_method
    resource[:vendored_modules_path] = File.expand_path(Pathname.new(__FILE__).dirname + '../../../' + 'puppet_x/dsc_resources')
    resource[:attributes] = nil
    context.debug("should_to_resource: #{resource.inspect}")
    resource
  end

  # Return a UUID with the dashes turned into underscores to enable the specifying of guaranteed-unique
  # variables in the PowerShell script.
  #
  # @returns [String] a uuid with underscores instead of dashes.
  def random_variable_name
    # PowerShell variables can't include dashes
    SecureRandom.uuid.gsub('-','_')
  end

  # Return a Hash containing all of the variables defined for instantiation as well as the Ruby hash for their
  # properties so they can be matched and replaced as needed.
  #
  # @returns [Hash] containing all instantiated variables and the properties that they define
  def instantiated_variables
    @@instantiated_variables ||= {}
  end

  # Look through a fully formatted string, replacing all instances where a value matches the formatted properties
  # of an instantiated variable with references to the variable instead. This allows us to pass complex and nested
  # CIM instances to the Invoke-DscResource parameter hash without constructing them *in* the hash.
  #
  # @params string [String] the string of text to search through for places an instantiated variable can be referenced
  # @returns [String] the string with references to instantiated variables instead of their properties
  def interpolate_variables(string)
    modified_string = string
    # Always replace later-created variables first as they sometimes were built from earlier ones
    instantiated_variables.reverse_each do |variable_name, ruby_definition|
      modified_string = modified_string.gsub(format(ruby_definition), "$#{variable_name}")
    end
    modified_string
  end

  # Parses a resource definition (as from `should_to_resource`) for any properties which are PowerShell
  # Credentials. As these values need to be serialized into PSCredential objects, return an array of
  # PowerShell lines, each of which instantiates a variable which holds the value as a PSCredential.
  # These credential variables can then be simply assigned in the parameter hash where needed.
  #
  # @param resource [Hash] a hash with the information needed to run `Invoke-DscResource`
  # @returns [String] An array of lines of PowerShell to instantiate PSCredentialObjects and store them in variables
  def prepare_credentials(resource)
    credentials_block = []
    resource[:parameters].each do |property_name, property_hash|
      next unless property_hash[:mof_type] == 'PSCredential'
      next if property_hash[:value].nil?
      variable_name = random_variable_name
      credential_hash = {
        'user' => property_hash[:value]['user'],
        'password' => escape_quotes(property_hash[:value]['password'].unwrap)
      }
      instantiated_variables.merge!(variable_name => credential_hash)
      credentials_block << format_pscredential(variable_name, credential_hash)
    end
    credentials_block.join("\n")
    credentials_block == [] ? '' : credentials_block
  end

  # Write a line of PowerShell which creates a PSCredential object and assigns it to a variable
  #
  # @params variable_name [String] the name of the Variable to assign the PSCredential object to
  # @params credential_hash [Hash] the Properties which define the PSCredential Object
  # @returns [String] A line of PowerShell which defines the PSCredential object and stores it to a variable
  def format_pscredential(variable_name, credential_hash)
    definition = "$#{variable_name} = New-PSCredential -User #{credential_hash['user']} -Password '#{credential_hash['password']}' # PuppetSensitive"
    definition
  end

  # Parses a resource definition (as from `should_to_resource`) for any properties which are CIM instances
  # whether at the top level or nested inside of other CIM instances, and, where they are discovered, adds
  # those objects to the instantiated_variables hash as well as returning a line of PowerShell code which
  # will create the CIM object and store it in a variable. This then allows the CIM instances to be assigned
  # by variable reference.
  #
  # @param resource [Hash] a hash with the information needed to run `Invoke-DscResource`
  # @returns [String] An array of lines of PowerShell to instantiate CIM Instances and store them in variables
  def prepare_cim_instances(resource)
    cim_instances_block = []
    resource[:parameters].each do |property_name, property_hash|
      next unless property_hash[:mof_is_embedded]
      # strip dsc_ from the beginning of the property name declaration
      name = property_name.to_s.gsub(/^dsc_/, '').to_sym
      # Process nested CIM instances first as those neeed to be passed to higher-order
      # instances and must therefore be declared before they must be referenced
      cim_instance_hashes = nested_cim_instances(property_hash[:value])
      cim_instance_hashes.flatten!.reject!{ |cim_instance_hash| cim_instance_hash.nil? }
      cim_instance_hashes.each do |instance|
        variable_name = random_variable_name
        instantiated_variables.merge!(variable_name => instance)
        class_name = instance['cim_instance_type']
        properties = instance.reject{ |k,v| k == 'cim_instance_type' }
        cim_instances_block << format_ciminstance(variable_name, class_name, properties)
      end
      # We have to handle arrays of CIM instances slightly differently
      if property_hash[:mof_type] =~ %r{\[\]$}
        class_name = property_hash[:mof_type].gsub('[]','')
        property_hash[:value].each do |hash|
          variable_name = random_variable_name
          instantiated_variables.merge!(variable_name => hash)
          cim_instances_block << format_ciminstance(variable_name, class_name, hash)
        end
      else
        variable_name = random_variable_name
        instantiated_variables.merge!(variable_name => property_hash[:value])
        class_name    = property_hash[:mof_type]
        cim_instances_block << format_ciminstance(variable_name, class_name, property_hash[:value])
      end
    end
    cim_instances_block == [] ? '' : cim_instances_block.join("\n")
  end

  # Recursively search for and return CIM instances nested in an enumerable
  #
  # @params enumerable [Enumerable] a hash or array which may contain CIM Instances
  # @returns [Hash] every discovered hash which does define a CIM Instance
  def nested_cim_instances(enumerable)
    enumerable.collect do |key, value|
      if key.is_a?(Hash) && key.key?('cim_instance_type')
        key
        # TODO: Are there any cim instancees 3 levels deep, or only 2?
        # if so, we should *also* keep searching and processing...
      elsif key.is_a?(Enumerable)
        nested_cim_instances(key)
      elsif value.is_a?(Enumerable)
        nested_cim_instances(value)
      end
    end
  end

  # Write a line of PowerShell which creates a CIM Instance and assigns it to a variable
  #
  # @params variable_name [String] the name of the Variable to assign the CIM Instance to
  # @params class_name [String] the CIM Class to instantiate
  # @params property_hash [Hash] the Properties which define the CIM Instance
  # @returns [String] A line of PowerShell which defines the CIM Instance and stores it to a variable
  def format_ciminstance(variable_name, class_name, property_hash)
    definition = "$#{variable_name} = New-CimInstance -ClientOnly -ClassName '#{class_name}' -Property #{format(property_hash)}"
    # AWFUL HACK to make New-CimInstance happy ; it can't parse an array unless it's an array of Cim Instances
    definition = definition.gsub("@(@{'cim_instance_type'","[CimInstance[]]@(@{'cim_instance_type'")
    definition = interpolate_variables(definition)
    definition
  end

  # Munge a resource definition (as from `should_to_resource`) into valid PowerShell which represents
  # the `InvokeParams` hash which will be splatted to `Invoke-DscResource`, interpolating all previously
  # defined variables into the hash.
  #
  # @param resource [Hash] a hash with the information needed to run `Invoke-DscResource`
  # @returns [String] A string representing the PowerShell definition of the InvokeParams hash
  def invoke_params(resource)
    params = {
      Name: resource[:dscmeta_resource_friendly_name],
      Method: resource[:dsc_invoke_method],
      Property: {}
    }
    if resource.key?(:dscmeta_module_version)
      params[:ModuleName] = {}
      params[:ModuleName][:ModuleName] = "#{resource[:vendored_modules_path]}/#{resource[:dscmeta_module_name]}/#{resource[:dscmeta_module_name]}.psd1"
      params[:ModuleName][:RequiredVersion] = resource[:dscmeta_module_version]
    else
      params[:ModuleName] = resource[:dscmeta_module_name]
    end
    resource[:parameters].each do |property_name, property_hash|
      # strip dsc_ from the beginning of the property name declaration
      name = property_name.to_s.gsub(/^dsc_/, '').to_sym
      if property_hash[:mof_type] == 'PSCredential'
        # format can't unwrap Sensitive strings nested in arbitrary hashes/etc, so make
        # the Credential hash interpolable as it will be replaced by a variable reference.
        params[:Property][name] = {
          'user' => property_hash[:value]['user'],
          'password' => escape_quotes(property_hash[:value]['password'].unwrap)
        }
      else
        params[:Property][name] = property_hash[:value]
      end
    end
    params_block = interpolate_variables("$InvokeParams = #{format(params)}")
    # HACK to make CIM instances work:
    resource[:parameters].select{|key,hash| hash[:mof_is_embedded] && hash[:mof_type] =~ %r{\[\]}}.each do |property_name, property_hash|
      formatted_property_hash = interpolate_variables(format(property_hash[:value]))
      params_block = params_block.gsub(formatted_property_hash,"[CimInstance[]]#{formatted_property_hash}")
    end
    params_block
  end

  # Given a resource definition (as from `should_to_resource`), return a PowerShell script which has
  # all of the appropriate function and variable definitions, which will call Invoke-DscResource, and
  # will correct munge the results for returning to Puppet as a JSON object.
  #
  # @param resource [Hash] a hash with the information needed to run `Invoke-DscResource`
  # @returns [String] A string representing the PowerShell script which will invoke the DSC Resource.
  def ps_script_content(resource)
    template_path = File.expand_path('../', __FILE__)
    # The preamble defines the helper functions and the response hash.
    preamble      = File.new(template_path + "/invoke_dsc_resource_preamble.ps1").read
    # The postscript defines the invocation error and result handling; expects `$InvokeParams` to be defined.
    postscript    = File.new(template_path + "/invoke_dsc_resource_postscript.ps1").read
    # The blocks define the variables to define for the postscript.
    credential_block    = prepare_credentials(resource)
    cim_instances_block = prepare_cim_instances(resource)
    parameters_block    = invoke_params(resource)

    content = [preamble, credential_block, cim_instances_block, parameters_block, postscript].join("\n")
    content
  end

  # Convert a Puppet/Ruby value into a PowerShell representation. Requires some slight additional
  # munging over what is provided in the ruby-pwsh library, as it does not handle unwrapping Sensitive
  # data types or interpolating Credentials.
  #
  # @params value [Object] The object to format into valid PowerShell
  # @returns [String] A string representation of the input value as valid PowerShell
  def format(value)
    if value.class.name == 'Puppet::Pops::Types::PSensitiveType::Sensitive'
      "'#{escape_quotes(value.unwrap)}' # PuppetSensitive"
    else
      Pwsh::Util.format_powershell_value(value)
    end
  end

  # Escape any nested single quotes in a Sensitive string
  #
  # @params text [String] the text to escape
  # @returns [String] the escaped text
  def escape_quotes(text)
    text.gsub("'", "''")
  end

  # While Puppet is aware of Sensitive data types, the PowerShell script is not
  # and so for debugging purposes must be redacted before being sent to debug
  # output but must *not* be redacted when sent to the PowerShell code manager.
  #
  # @params text [String] the text to redact
  # @returns [String] the redacted text
  def redact_secrets(text)
    # Every secret unwrapped in this module will unwrap as "'secret' # PuppetSensitive" and, currently,
    # no known resources specify a SecureString instead of a PSCredential object. We therefore only
    # need to redact strings which look like password declarations.
    modified_text = text.gsub(%r{(?<=-Password )'.+' # PuppetSensitive}, "'#<Sensitive [value redacted]>'")
    if modified_text =~ %r{'.+' # PuppetSensitive}
      # Something has gone wrong, error loudly?
    else
      modified_text
    end
  end


  # Instantiate a PowerShell manager via the ruby-pwsh library and use it to invoke PowerShell.
  # Definiing it here allows re-use of a single instance instead of continually instantiating and
  # tearing a new instance down for every call.
  def ps_manager
    debug_output = Puppet::Util::Log.level == :debug
    # TODO: Allow you to specify an alternate path, either to pwsh generally or a specific pwsh path.
    Pwsh::Manager.instance(Pwsh::Manager.powershell_path, Pwsh::Manager.powershell_args, debug: debug_output)
  end
end
