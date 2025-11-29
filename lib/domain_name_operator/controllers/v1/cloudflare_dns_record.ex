defmodule DomainNameOperator.Controller.V1.CloudflareDnsRecord do
  @moduledoc """
  DomainNameOperator: CloudflareDnsRecord CRD.

  ## Kubernetes CRD Spec

  By default all CRD specs are assumed from the module name, you can override them using attributes.

  ### Examples
  ```
  # Kubernetes API version of this CRD, defaults to value in module name
  @version "v2alpha1"

  # Kubernetes API group of this CRD, defaults to "domain-name-operator.example.com"
  @group "kewl.example.io"

  The scope of the CRD. Defaults to `:namespaced`
  @scope :cluster

  CRD names used by kubectl and the kubernetes API
  @names %{
    plural: "foos",
    singular: "foo",
    kind: "Foo",
    shortNames: ["f", "fo"]
  }
  ```

  ## Declare RBAC permissions used by this module

  RBAC rules can be declared using `@rule` attribute and generated using `mix bonny.manifest`

  This `@rule` attribute is cumulative, and can be declared once for each Kubernetes API Group.

  ### Examples

  ```
  @rule {apiGroup, resources_list, verbs_list}

  @rule {"", ["pods", "secrets"], ["*"]}
  @rule {"apiextensions.k8s.io", ["foo"], ["*"]}
  ```

  ## Add additional printer columns

  Kubectl uses server-side printing. Columns can be declared using `@additional_printer_columns` and generated using `mix bonny.manifest`

  [Additional Printer Columns docs](https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/#additional-printer-columns)

  ### Examples

  ```
  @additional_printer_columns [
    %{
      name: "test",
      type: "string",
      description: "test",
      JSONPath: ".spec.test"
    }
  ]
  ```

  """

  #
  # Example Payload:
  #   %{
  #     "apiVersion" => "domain-name-operator.tamx.org/v1",
  #     "kind" => "CloudflareDnsRecord",
  #     "metadata" => %{
  #       "annotations" => %{
  #         "kubectl.kubernetes.io/last-applied-configuration" => %{
  #           "apiVersion" => "hello-operator.example.com/v1",
  #           "kind" => "Greeting",
  #           "metadata" => %{"annotations" => %{}, "name" => "hello-server", "namespace" => "default"},
  #           "spec" => %{"greeting" => "Howdy"}
  #         }
  #       },
  #       "clusterName" => "",
  #       "creationTimestamp" => "2018-12-30T17:17:58Z",
  #       "generation" => 1,
  #       "name" => "some-service-dns-record",
  #       "namespace" => "default",
  #       "resourceVersion" => "1359609",
  #       "selfLink" => "/apis/hello-operator.example.com/v1/namespaces/default/greetings/hello-server",
  #       "uid" => "daa7e59b-0c56-11e9-bd27-025000000001"
  #     },
  #     "spec" => %{
  #       "namespace" => "domain-name-operator-staging",
  #       "serviceName" => "Howdy",
  #       "hostName" => "domain-name-operator-staging",
  #       "domain" => "ameelio.xyz",
  #       "zoneId" => "abcdefg",
  #       "proxied" => true
  #     }
  #   }
  #

  use Bonny.Controller

  alias CloudflareApi.DnsRecord
  alias DomainNameOperator.Utils

  alias DomainNameOperator.Utils.Logger
  alias DomainNameOperator.ProcessRecordException

  @group "domain-name-operator.tamx.org"
  @version "v1"

  @scope :cluster
  @names %{
    plural: "cloudflarednsrecords",
    singular: "cloudflarednsrecord",
    kind: "CloudflareDnsRecord",
    shortNames: ["dns"]
  }

  # @rule {"", ["pods", "configmap"], ["*"]}
  # @rule {"", ["secrets"], ["create"]}

  @rule {"", ["services"], ["*"]}

  @doc """
  Handles an `ADDED` event
  """
  @spec add(map()) :: :ok | {:ok, any()} | {:error, any()}
  @impl Bonny.Controller
  def add(%{} = cloudflarednsrecord) do
    Logger.info(
      IO.ANSI.format([
        :green,
        Utils.FromEnv.mfa_str(__ENV__) <> " --- Handling Add --- ",
        :reset
      ])
    )

    process_record(cloudflarednsrecord)
  end

  @doc """
  Handles a `MODIFIED` event
  """
  @spec modify(map()) :: :ok | {:ok, any()} | {:error, any()}
  @impl Bonny.Controller
  def modify(%{} = cloudflarednsrecord) do
    Logger.info(
      IO.ANSI.format([
        :green,
        Utils.FromEnv.mfa_str(__ENV__) <> " --- Handling Modify --- ",
        :reset
      ])
    )

    process_record(cloudflarednsrecord)
  end

  @doc """
  Handles a `DELETED` event
  """
  @spec delete(map()) :: :ok | {:ok, any()} | {:error, any()}
  @impl Bonny.Controller
  def delete(%{} = cloudflarednsrecord) do
    Logger.info(
      IO.ANSI.format([
        :green,
        Utils.FromEnv.mfa_str(__ENV__) <> " --- Handling Delete --- ",
        :reset
      ])
    )

    # Parse the cloudflarednsrecord into a DNS record
    {:ok, record} = parse(cloudflarednsrecord)

    with {:ok, record} <- parse(cloudflarednsrecord),
         {:ok, cf} <- cloudflare_ops().delete_record(record) do
      Logger.info(
        Utils.FromEnv.mfa_str(__ENV__) <> ": Deleted record: cf=#{Utils.map_to_string(cf)}"
      )

      {:ok, record}
    else
      err ->
        Utils.Logger.error(
          __ENV__,
          "Error deleting record: err='#{err}' record=#{Utils.map_to_string(record)}"
        )

        handle_process_record_error(err, cloudflarednsrecord)
    end
  end

  @doc """
  Called periodically for each existing CustomResource to allow for reconciliation.
  """
  @spec reconcile(map()) :: :ok | {:ok, any()} | {:error, any()}
  @impl Bonny.Controller
  def reconcile(%{} = cloudflarednsrecord) do
    Logger.info(
      IO.ANSI.format([
        :green,
        Utils.FromEnv.mfa_str(__ENV__) <> " --- Handling Reconcile --- ",
        :reset
      ])
    )

    process_record(cloudflarednsrecord)
  end

  def process_record(cloudflarednsrecord) do
    Utils.Logger.info(__ENV__, "Processing record: #{Utils.to_string(cloudflarednsrecord)}")

    # Parse the cloudflarednsrecord into a DNS record
    with {:ok, record} <- parse(cloudflarednsrecord),
         {:ok, cf} <- cloudflare_ops().add_or_update_record(record) do
      Logger.info(
        Utils.FromEnv.mfa_str(__ENV__) <>
          ": Added or updated record: cf=#{Utils.map_to_string(cf)}"
      )

      {:ok, record}
    else
      {:error, :no_ip, %{namespace: namespace, name: name}} ->
        parse_record_error(:no_ip, namespace, name, cloudflarednsrecord)

      {:error, :bad_ip} ->
        parse_record_error(:bad_ip, cloudflarednsrecord)

      {:error, :service_not_found, %{namespace: namespace, name: name}} ->
        process_record_error(:service_not_found, namespace, name, cloudflarednsrecord)

      {:error, err, %{namespace: namespace, name: name}} ->
        process_record_error(:service_general, err, namespace, name, cloudflarednsrecord)

      {:error, [%{"code" => 9106}]} ->
        process_record_error(:cloudflare_auth_missing, cloudflarednsrecord)

      {:error, err} ->
        process_record_error(err, cloudflarednsrecord)

      err ->
        handle_process_record_error(err, cloudflarednsrecord)
    end
  end

  def handle_process_record_error(cloudflarednsrecord, error) do
    case error do
      {:error, :no_ip, %{namespace: namespace, name: name}} ->
        parse_record_error(:no_ip, namespace, name, cloudflarednsrecord)

      {:error, :bad_ip} ->
        parse_record_error(:bad_ip, cloudflarednsrecord)

      {:error, :service_not_found, %{namespace: namespace, name: name}} ->
        process_record_error(:service_not_found, namespace, name, cloudflarednsrecord)

      {:error, err, %{namespace: namespace, name: name}} ->
        process_record_error(:service_general, err, namespace, name, cloudflarednsrecord)

      {:error, [%{"code" => 9106}]} ->
        process_record_error(:cloudflare_auth_missing, cloudflarednsrecord)

      {:error, err} ->
        process_record_error(err, cloudflarednsrecord)

      err ->
        process_record_error(err, cloudflarednsrecord)
    end
  end

  def process_record_exception(type, cloudflarednsrecord, msg, opts) do
    tags =
      opts
      |> Keyword.get(:tags, %{})
      |> Map.merge(%{error_type: type})

    extra =
      opts
      |> Keyword.get(:extra, %{})
      |> Map.merge(%{type: type, cloudflarednsrecord: cloudflarednsrecord})

    try do
      raise ProcessRecordException, msg: msg
    rescue
      ex ->
        case sentry_client().capture_exception(ex,
               stacktrace: __STACKTRACE__,
               tags: tags,
               extra: extra
             ) do
          {:ok, _task} ->
            ex

          err ->
            Utils.Logger.error(
              __ENV__,
              "Couldn't send exception to sentry:  err='#{Utils.to_string(err)}' type='#{Utils.to_string(type)}' msg='#{msg}' cloudflarednsrecord='#{Utils.to_string(cloudflarednsrecord)}'"
            )
        end
    end
  end

  def process_record_error(:service_not_found, namespace, name, cloudflarednsrecord) do
    msg =
      "Service '#{name}' was not found in namespace '#{namespace}'.  Could not get IP address needed to create DNS record"

    Utils.Logger.error(
      __ENV__,
      "#{msg}.  cloudflarednsrecord=#{Utils.to_string(cloudflarednsrecord)}"
    )

    process_record_exception(:service_not_found, cloudflarednsrecord, msg,
      extra: %{
        service_namespace: namespace,
        service_name: name
      }
    )

    {:error, :service_not_found}
  end

  def process_record_error(:service_general, err, namespace, name, cloudflarednsrecord) do
    msg = "Service '#{name}' in namespace '#{namespace}' had error '#{err}'"

    Utils.Logger.error(
      __ENV__,
      "#{msg}.  cloudflarednsrecord=#{Utils.to_string(cloudflarednsrecord)}"
    )

    process_record_exception(:service_general, cloudflarednsrecord, msg,
      extra: %{
        service_namespace: namespace,
        service_name: name
      }
    )

    {:error, :service_general}
  end

  def process_record_error(:cloudflare_auth_missing, cloudflarednsrecord) do
    msg =
      "Could not authenticate to Cloudflare.  API token may be missing.  Double check that environment variable CLOUDFLARE_API_TOKEN is set."

    Utils.Logger.error(__ENV__, msg)

    process_record_exception(:cloudflare_auth_missing, cloudflarednsrecord, msg, extra: %{})

    {:error, :cloudflare_auth_missing}
  end

  def process_record_error(error, cloudflarednsrecord) do
    msg = "Encountered error '#{Utils.to_string(error)}' processing record."

    Utils.Logger.error(
      __ENV__,
      "#{msg}.  cloudflarednsrecord=#{Utils.to_string(cloudflarednsrecord)}"
    )

    process_record_exception(error, cloudflarednsrecord, msg, extra: %{})

    {:error, error}
  end

  def parse_record_error(:no_ip, namespace, name, cloudflarednsrecord) do
    msg =
      "Service '#{name}' in namespace '#{namespace}' has no IP address.  This can happen if the service is newly created and is still being provisioned by DO, but if it's been more than 5 to 10 minutes could mean there's an issue that needs investigation.  Could not get IP address needed to create DNS record"

    Utils.Logger.error(
      __ENV__,
      "#{msg}.  cloudflarednsrecord=#{Utils.to_string(cloudflarednsrecord)}"
    )

    process_record_exception(:no_ip, cloudflarednsrecord, msg, extra: %{})

    {:error, :no_ip}
  end

  def parse_record_error(:bad_ip, cloudflarednsrecord) do
    msg = "Service has an invalid IP address!"

    Utils.Logger.error(
      __ENV__,
      "#{msg}.  cloudflarednsrecord=#{Utils.to_string(cloudflarednsrecord)}"
    )

    process_record_exception(:bad_ip, cloudflarednsrecord, msg, extra: %{})

    {:error, :bad_ip}
  end

  def parse_record_error(error, cloudflarednsrecord) do
    msg = ": Error processing cloudflarednsrecord: error='#{Utils.to_string(error)}'"

    Utils.Logger.error(
      __ENV__,
      "#{msg} cloudflarednsrecord=#{Utils.to_string(cloudflarednsrecord)}"
    )

    process_record_exception(error, cloudflarednsrecord, msg, extra: %{})

    {:error, error}
  end

  #
  # Example Payload:
  #   %{
  #     "apiVersion" => "domain-name-operator.tamx.org/v1",
  #     "kind" => "CloudflareDnsRecord",
  #     "metadata" => %{
  #       "annotations" => %{
  #         "kubectl.kubernetes.io/last-applied-configuration" => %{
  #           "apiVersion" => "hello-operator.example.com/v1",
  #           "kind" => "Greeting",
  #           "metadata" => %{"annotations" => %{}, "name" => "hello-server", "namespace" => "default"},
  #           "spec" => %{"greeting" => "Howdy"}
  #         }
  #       },
  #       "clusterName" => "",
  #       "creationTimestamp" => "2018-12-30T17:17:58Z",
  #       "generation" => 1,
  #       "name" => "some-service-dns-record",
  #       "namespace" => "default",
  #       "resourceVersion" => "1359609",
  #       "selfLink" => "/apis/hello-operator.example.com/v1/namespaces/default/greetings/hello-server",
  #       "uid" => "daa7e59b-0c56-11e9-bd27-025000000001"
  #     },
  #     "spec" => %{
  #       "namespace" => "domain-name-operator-staging",
  #       "serviceName" => "Howdy",
  #       "hostName" => "domain-name-operator-staging",
  #       "domain" => "ameelio.xyz",
  #       "zoneId" => "abcdefg",
  #       "proxied" => true
  #     }
  #   }
  #

  defp crd_to_cloudflare_record(%{
         "metadata" => %{"name" => _name},
         "spec" => %{
           "namespace" => _ns,
           "serviceName" => _service_name,
           "hostName" => _hostname,
           "domain" => _domain,
           "zoneId" => _zone_id,
           "proxied" => _proxied
         }
       }) do
    Logger.debug(__ENV__, "crd_to_cloudflare_record: (todo addme)")
  end

  def default_zone_id do
    case Application.fetch_env!(:domain_name_operator, :cloudflare_default_zone_id) do
      z when is_binary(z) -> z
      _ -> raise "Default Zone ID isn't set and record doesn't include a zone ID"
    end
  end

  def default_domain do
    case Application.fetch_env!(:domain_name_operator, :cloudflare_default_domain) do
      d when is_binary(d) -> d
      _ -> raise "Default domain isn't set and record doesn't include domain!"
    end
  end

  def parse(
        %{
          "metadata" => %{"name" => _name},
          "spec" => %{
            "namespace" => ns,
            "serviceName" => service_name,
            "hostName" => hostname,
            "domain" => domain,
            "zoneId" => zone_id,
            "proxied" => proxied
          }
        } = record
      ) do
    Logger.debug(
      __ENV__,
      "Parsing record: namespace='#{ns}' serviceName='#{service_name}' hostName='#{hostname}' domain='#{domain}' zoneId='#{zone_id}'"
    )

    with {:ok, hostname, domain} <- validate_hostname(hostname, domain),
         {:ok, service} <- get_service(ns, service_name),
         {:ok, ip} <- parse_svc_ip(service),
         {:ok, _} <- is_ipv4?(ip),
         {:ok, _} <- validate_domain(zone_id, domain),
         {:ok, cfar} <- assemble_cf_a_record(zone_id, hostname, domain, ip, proxied) do
      {:ok, cfar}
    else
      {:error, err, %{} = attrs} -> {:error, err, attrs}
      {:error, err} -> {:error, err}
      err -> {:error, err}
    end
  end

  # Without zone ID, will set to default
  def parse(
        %{
          "metadata" => %{"name" => _name},
          "spec" => %{
            "namespace" => _ns,
            "serviceName" => _service_name,
            "hostName" => _hostname,
            "domain" => _domain,
            "proxied" => _proxied
          }
        } = record
      ) do
    record
    |> update_in(["spec", "zoneId"], fn _ -> default_zone_id() end)
    |> parse()
  end

  # Without Domain, will set to default
  def parse(
        %{
          "metadata" => %{"name" => _name},
          "spec" => %{
            "namespace" => _ns,
            "serviceName" => _service_name,
            "hostName" => hostname,
            "proxied" => proxied
          }
        } = record
      ) do
    # First try to extract the domain from the hostname.
    # If not present, then use the default domain
    record
    |> update_in(["spec", "domain"], fn _ -> extract_domain(hostname) end)
    |> parse()
  end

  # Without namespace, will set to same namespace as our object
  def parse(
        %{
          "metadata" => %{"name" => _name, "namespace" => ns},
          "spec" => %{
            "serviceName" => _service_name,
            "hostName" => _hostname,
            "proxied" => proxied
          }
        } = record
      ) do
    record
    |> update_in(["spec", "namespace"], fn _ -> ns end)
    |> parse()
  end

  # Without proxied, will default to false
  def parse(
        %{
          "metadata" => %{"name" => _name, "namespace" => ns},
          "spec" => %{
            "serviceName" => _service_name,
            "hostName" => _hostname
          }
        } = record
      ) do
    record
    |> update_in(["spec", "proxied"], fn _ -> false end)
    |> parse()
  end

  def parse(record) do
    Logger.error(
      Utils.FromEnv.mfa_str(__ENV__) <>
        ": parse()/1 invoked with unhandled argument structure.  Make sure the cloudflarednsrecord object you created in k8s has the expected structure:  #{Utils.map_to_string(record)}"
    )

    {:error, :unhandled_structure}
  end

  defp is_ipv4?(ip) do
    case Iptools.is_ipv4?(ip) do
      true -> {:ok, true}
      false -> {:error, :bad_ip}
    end
  end

  # For a single IP address
  defp parse_svc_ip(%{
         "status" =>
           %{
             "loadBalancer" => %{
               "ingress" => [
                 %{"ip" => ip}
               ]
             }
           } = status
       }) do
    Logger.debug(__ENV__, "parse_svc_ip: status='#{Utils.map_to_string(status)}'")

    {:ok, ip}
  end

  # For multiple IP addresses, especially now that DO added IPv6 support
  defp parse_svc_ip(%{
         "status" =>
           %{
             "loadBalancer" => %{
               "ingress" => ip_addrs
             }
           } = status
       } = service) do
    Logger.debug(
      __ENV__,
      "parse_svc_ip: Parsing service with multiple IP addresses.  Looking for first IPv4 address.  status='#{Utils.map_to_string(status)}'"
    )

    # Iterate through the ip_addrs map and find the first IPv4 address
    ipv4_address =
      ip_addrs
      |> Enum.map(& &1["ip"])
      |> Enum.find(&is_ipv4?/1)

    # Check if we found an IPv4 address.  If not, ipv4_address will be nil
    case ipv4_address do
      nil ->
        Utils.Logger.warning(
          __ENV__,
          "Service object does not have an IPv4 address.  This can sometimes take a few minutes on a newly created service but if it's been more than 5 or so minutes, it might be a problem.  The IP addresses assigned are:  ip_addrs='#{Utils.to_string(ip_addrs)}'  Service='#{Utils.to_string(service)}'"
        )

        {:error, :no_ip,
         %{namespace: service["metadata"]["namespace"], name: service["metadata"]["name"]}}

      ip ->
        {:ok, ip}
    end
  end

  defp parse_svc_ip(service) do
    Utils.Logger.warning(
      __ENV__,
      "Service object does not have an IP address.  This can sometimes take a few minutes on a newly created service but if it's been more than 5 or so minutes, it might be a problem.  Service='#{Utils.to_string(service)}'"
    )

    {:error, :no_ip,
     %{namespace: service["metadata"]["namespace"], name: service["metadata"]["name"]}}
  end

  defp assemble_cf_a_record(zone_id, hostname, domain, ip, proxied) do
    Logger.debug(
      __ENV__,
      "assemble_cf_a_record: zone_id='#{zone_id}' hostname='#{hostname}' ip='#{ip}' proxied='#{proxied}'"
    )

    cfar = %DnsRecord{
      zone_id: zone_id,
      hostname: hostname,
      zone_name: domain,
      # ip: List.first(service.status.loadBalancer.ingress).ip
      ip: ip,
      proxied: proxied
    }

    {:ok, cfar}
  end

  defp get_service(namespace, name) do
    k8s_client().get_service(namespace, name)
  end

  def extract_domain(hostname) do
    # Note:  This currently only supports one level of sub-domain!
    # i.e.  app.tamx.org is ok, some.app.tamx.org is not, nor is tamx.org
    reg = ~r{^([a-zA-Z0-9-]+)\.([a-zA-Z0-9-]+)\.([a-zA-Z0-9-]+)$}

    case Regex.run(reg, hostname) do
      [_orig, _hn, name, tld] ->
        Utils.Logger.debug(__ENV__, "Extracted domain #{name}.#{tld} from hostname #{hostname}")
        name <> "." <> tld

      _ ->
        Utils.Logger.warning(
          __ENV__,
          "Attempted to extract domain from hostname '#{hostname}' but extraction failed.  Using default domain of #{default_domain()}"
        )

        default_domain()
    end
  end

  defp validate_hostname(hostname, domain) do
    Logger.debug(__ENV__, "hostname='#{hostname}'")

    cond do
      String.ends_with?(hostname, domain) ->
        Logger.debug(
          __ENV__,
          "hostname='#{hostname}' ends with domain='#{domain}' already.  Not changing"
        )

        {:ok, hostname, domain}

      true ->
        new_hostname = "#{hostname}.#{domain}"

        Logger.info(
          Utils.FromEnv.mfa_str(__ENV__) <>
            ": hostname='#{hostname}' does not end with domain.  Using hostname '#{new_hostname}'"
        )

        {:ok, new_hostname, domain}
    end
  end

  defp validate_domain(zone_id, domain) do
    Logger.debug(__ENV__, ": zone_id='#{zone_id}' domain='#{domain}'")
    # TODO: make sure that the `zone_name` for the `zone_id` matches `domain`
    {:ok, true}
  end

  defp k8s_client do
    Application.get_env(:domain_name_operator, :k8s_client, DomainNameOperator.K8sClient)
  end

  defp sentry_client do
    Application.get_env(
      :domain_name_operator,
      :sentry_client,
      DomainNameOperator.SentryClient
    )
  end

  defp cloudflare_ops do
    Application.get_env(:domain_name_operator, :cloudflare_ops, DomainNameOperator.CloudflareOps)
  end
end
