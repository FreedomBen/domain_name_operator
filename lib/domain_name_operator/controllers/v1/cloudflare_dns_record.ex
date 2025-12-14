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

  use Bonny.ControllerV2

  alias CloudflareApi.DnsRecord
  alias DomainNameOperator.Utils

  alias DomainNameOperator.Utils.Logger
  alias DomainNameOperator.ProcessRecordException

  step(Bonny.Pluggable.SkipObservedGenerations)
  step(:handle_event)

  @group "domain-name-operator.tamx.org"
  @version "v1"

  @scope :cluster
  @names %{
    plural: "cloudflarednsrecords",
    singular: "cloudflarednsrecord",
    kind: "CloudflareDnsRecord",
    shortNames: ["dns"]
  }
  @event_message_limit 1024
  @history_limit 10

  @doc false
  def api_group, do: @group

  @doc false
  def api_version, do: "#{@group}/#{@version}"

  @doc false
  def crd_scope, do: @scope

  @doc false
  def crd_names, do: @names

  @impl Bonny.ControllerV2
  def rbac_rules do
    [
      to_rbac_rule({"", ["services"], ["*"]}),
      to_rbac_rule(
        {@group, [@names.plural, "#{@names.plural}/status"],
         ["get", "list", "watch", "update", "patch"]}
      ),
      to_rbac_rule({"", ["events"], ["create", "patch", "update"]}),
      to_rbac_rule({"events.k8s.io", ["events"], ["create", "patch", "update"]})
    ]
  end

  @doc false
  def handle_event(%Bonny.Axn{action: action, resource: resource} = axn, _opts)
      when action in [:add, :modify, :reconcile] do
    success_message = "Cloudflare DNS record reconciled successfully."

    case process_record(resource) do
      {:ok, record} ->
        axn
        |> put_success_status(resource, record, action,
          reason: "CloudflareDnsRecordSynced",
          message: success_message
        )
        |> success_event(reason: "CloudflareDnsRecordSynced", message: success_message)

      {:error, reason} ->
        failure_message =
          build_event_failure_message("Failed to reconcile Cloudflare DNS record", reason)

        axn
        |> put_failure_status(resource, reason, action, failure_message)
        |> failure_event(reason: "CloudflareDnsRecordFailed", message: failure_message)
    end
  end

  def handle_event(%Bonny.Axn{action: :delete, resource: resource} = axn, _opts) do
    success_message = "Cloudflare DNS record deleted successfully."

    case delete(resource) do
      {:ok, record} ->
        axn
        |> put_success_status(resource, record, :delete,
          reason: "CloudflareDnsRecordDeleted",
          message: success_message,
          state: "absent"
        )
        |> success_event(reason: "CloudflareDnsRecordDeleted", message: success_message)

      {:error, reason} ->
        failure_message =
          build_event_failure_message("Failed to delete Cloudflare DNS record", reason)

        axn
        |> put_failure_status(resource, reason, :delete, failure_message)
        |> failure_event(reason: "CloudflareDnsRecordDeleteFailed", message: failure_message)
    end
  end

  @doc """
  Handles an `ADDED` event. Kept for backwards-compatible direct usage and
  exercised heavily by the test suite.
  """
  @spec add(map()) :: :ok | {:ok, any()} | {:error, any()}
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
  Handles a `MODIFIED` event.
  """
  @spec modify(map()) :: :ok | {:ok, any()} | {:error, any()}
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
  Handles a `DELETED` event.
  """
  @spec delete(map()) :: :ok | {:ok, any()} | {:error, any()}
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
          "Error deleting record: err='#{Utils.to_string(err)}' record=#{Utils.map_to_string(record)}"
        )

        handle_process_record_error(err, cloudflarednsrecord)
    end
  end

  @doc """
  Called periodically for each existing CustomResource to allow for reconciliation.
  """
  @spec reconcile(map()) :: :ok | {:ok, any()} | {:error, any()}
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

      {:ok, merge_record(record, cf)}
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
    msg =
      "Service '#{name}' in namespace '#{namespace}' had error '#{Utils.to_string(err)}'"

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

  def parse(%{
        "metadata" => %{"name" => _name},
        "spec" => %{
          "namespace" => ns,
          "serviceName" => service_name,
          "hostName" => hostname,
          "domain" => domain,
          "zoneId" => zone_id,
          "proxied" => proxied
        }
      }) do
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
            "proxied" => _proxied
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
            "proxied" => _proxied
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
          "metadata" => %{"name" => _name, "namespace" => _ns},
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
  defp parse_svc_ip(
         %{
           "status" =>
             %{
               "loadBalancer" => %{
                 "ingress" => ip_addrs
               }
             } = status
         } = service
       ) do
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

  defp put_success_status(axn, resource, record, action, opts) do
    message = Keyword.fetch!(opts, :message)
    reason = Keyword.get(opts, :reason, "SyncSucceeded")
    state = Keyword.get(opts, :state, "present")
    hostname = record_hostname(record) || resource_hostname(resource)
    now = iso_timestamp()

    axn
    |> update_status(fn status ->
      status
      |> put_observed_generation(resource)
      |> Map.put("conditions", upsert_synced_condition(status, "True", reason, message, now))
      |> Map.put("sync", sync_success(now))
      |> Map.put("cloudflare", cloudflare_snapshot(record, resource, hostname, state))
      |> Map.put(
        "history",
        prepend_history(
          status,
          history_entry(action, "success", message, record, resource, hostname, state, now)
        )
      )
    end)
  end

  defp put_failure_status(axn, resource, reason_term, action, message) do
    reason = failure_condition_reason(action)
    hostname = resource_hostname(resource)
    now = iso_timestamp()

    axn
    |> update_status(fn status ->
      status
      |> put_observed_generation(resource)
      |> Map.put("conditions", upsert_synced_condition(status, "False", reason, message, now))
      |> Map.put("sync", sync_failure(status, now, reason_term, message))
      |> Map.put("cloudflare", cloudflare_snapshot(nil, resource, hostname, "error"))
      |> Map.put(
        "history",
        prepend_history(
          status,
          history_entry(action, "error", message, nil, resource, hostname, "error", now)
        )
      )
    end)
  end

  defp history_entry(action, status, message, record, resource, hostname, state, timestamp) do
    %{
      "timestamp" => timestamp,
      "action" => Atom.to_string(action),
      "status" => status,
      "message" => message
    }
    |> maybe_put("hostname", hostname)
    |> maybe_put("zoneId", record_zone_id(record) || resource_zone_id(resource))
    |> maybe_put("cloudflareRecordId", record_id(record))
    |> maybe_put("ip", record_ip(record))
    |> maybe_put("proxied", record_proxied(record))
    |> maybe_put("state", state)
  end

  defp prepend_history(status, entry) do
    status
    |> Map.get("history", [])
    |> List.wrap()
    |> List.insert_at(0, entry)
    |> Enum.take(@history_limit)
  end

  defp upsert_synced_condition(status, condition_status, reason, message, timestamp) do
    existing =
      status
      |> Map.get("conditions", [])
      |> List.wrap()
      |> Enum.reject(&(&1["type"] == "Synced"))

    [
      %{
        "type" => "Synced",
        "status" => condition_status,
        "reason" => reason,
        "message" => message,
        "lastTransitionTime" => timestamp
      }
      | existing
    ]
  end

  defp sync_success(timestamp) do
    %{
      "lastAttemptedAt" => timestamp,
      "lastSuccessfulAt" => timestamp,
      "lastError" => %{},
      "retryCount" => 0
    }
  end

  defp sync_failure(status, timestamp, reason, message) do
    retry_count = get_in(status, ["sync", "retryCount"]) || 0

    %{
      "lastAttemptedAt" => timestamp,
      "lastSuccessfulAt" => get_in(status, ["sync", "lastSuccessfulAt"]),
      "lastError" => %{
        "reason" => reason_to_string(reason),
        "message" => message
      },
      "retryCount" => retry_count + 1
    }
  end

  defp reason_to_string(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp reason_to_string(reason) when is_binary(reason), do: reason
  defp reason_to_string(reason), do: inspect(reason)

  defp failure_condition_reason(:delete), do: "CloudflareDnsRecordDeleteFailed"
  defp failure_condition_reason(_), do: "CloudflareDnsRecordFailed"

  defp cloudflare_snapshot(record, resource, hostname, state) do
    %{"state" => state}
    |> maybe_put("hostname", hostname)
    |> maybe_put("zoneId", record_zone_id(record) || resource_zone_id(resource))
    |> maybe_put("recordId", record_id(record))
    |> maybe_put("zoneName", record_zone_name(record))
    |> maybe_put("ip", record_ip(record))
    |> maybe_put("proxied", record_proxied(record))
    |> maybe_put("ttl", record_ttl(record))
  end

  defp record_zone_id(%DnsRecord{zone_id: zone_id}) when is_binary(zone_id) and zone_id != "",
    do: zone_id

  defp record_zone_id(_), do: nil

  defp record_zone_name(%DnsRecord{zone_name: zone_name}) when is_binary(zone_name), do: zone_name
  defp record_zone_name(_), do: nil

  defp record_id(%DnsRecord{id: id}) when is_binary(id), do: id
  defp record_id(_), do: nil

  defp record_ip(%DnsRecord{ip: ip}) when is_binary(ip), do: ip
  defp record_ip(_), do: nil

  defp record_proxied(%DnsRecord{proxied: proxied}) when is_boolean(proxied), do: proxied
  defp record_proxied(_), do: nil

  defp record_ttl(%DnsRecord{ttl: ttl}) when is_integer(ttl), do: ttl
  defp record_ttl(_), do: nil

  defp record_hostname(%DnsRecord{hostname: hostname}) when is_binary(hostname), do: hostname
  defp record_hostname(_), do: nil

  defp resource_zone_id(%{"spec" => %{"zoneId" => zone_id}}) when is_binary(zone_id),
    do: zone_id

  defp resource_zone_id(_), do: nil

  defp resource_hostname(%{"spec" => %{"hostName" => hostname, "domain" => domain}})
       when is_binary(hostname) and is_binary(domain) do
    cond do
      String.ends_with?(hostname, domain) -> hostname
      true -> "#{hostname}.#{domain}"
    end
  end

  defp resource_hostname(%{"spec" => %{"hostName" => hostname}}) when is_binary(hostname),
    do: hostname

  defp resource_hostname(_), do: nil

  defp put_observed_generation(status, resource) do
    case resource_generation(resource) do
      nil -> status
      generation -> Map.put(status, "observedGeneration", generation)
    end
  end

  defp resource_generation(%{"metadata" => %{"generation" => generation}})
       when is_integer(generation),
       do: generation

  defp resource_generation(_), do: nil

  defp iso_timestamp do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp merge_record(%DnsRecord{} = record, %DnsRecord{} = returned) do
    merged =
      record
      |> Map.from_struct()
      |> Map.merge(Map.from_struct(returned), fn _k, _v1, v2 -> v2 end)

    struct(DnsRecord, merged)
  end

  defp merge_record(%DnsRecord{} = record, %{} = returned) do
    try do
      returned
      |> CloudflareApi.DnsRecord.from_cf_json()
      |> merge_record(record)
    rescue
      _ -> record
    end
  end

  defp merge_record(record, _returned), do: record

  defp build_event_failure_message(prefix, reason) do
    "#{prefix}: #{format_event_reason(reason)}"
    |> truncate_event_message()
  end

  defp format_event_reason(reason) do
    inspect(reason, printable_limit: truncatable_print_limit())
  rescue
    _ -> "unprintable error"
  end

  defp truncatable_print_limit do
    max(@event_message_limit - 64, 128)
  end

  defp truncate_event_message(message) when is_binary(message) do
    if String.length(message) <= @event_message_limit do
      message
    else
      String.slice(message, 0, @event_message_limit - 3) <> "..."
    end
  end
end
