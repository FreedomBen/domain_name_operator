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
  #       "namespace" => "malan-staging",
  #       "serviceName" => "Howdy",
  #       "hostName" => "malan-staging",
  #       "domain" => "ameelio.xyz",
  #       "zoneId" => "abcdefg",
  #       "proxied" => true
  #     }
  #   }
  #

  use Bonny.Controller

  alias CloudflareApi.DnsRecord
  alias DomainNameOperator.{Utils, CloudflareOps}

  alias DomainNameOperator.Utils.Logger

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

    # Parse the cloudflarednsrecord into a DNS record
    {:ok, record} = parse(cloudflarednsrecord)

    with {:ok, cf} <- CloudflareOps.add_or_update_record(record) do
      Logger.info(
        Utils.FromEnv.mfa_str(__ENV__) <> ": Added or updated record: cf=#{Utils.map_to_string(cf)}"
      )

      {:ok, record}
    else
      err ->
        Logger.error(
          Utils.FromEnv.mfa_str(__ENV__) <>
            ": Error adding or updating record: err='#{err}' record=#{Utils.map_to_string(record)}"
        )

        {:error, err}
    end
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

    # Parse the cloudflarednsrecord into a DNS record
    {:ok, record} = parse(cloudflarednsrecord)

    with {:ok, cf} <- CloudflareOps.add_or_update_record(record) do
      Logger.info(
        Utils.FromEnv.mfa_str(__ENV__) <> ": Added or updated record: cf=#{Utils.map_to_string(cf)}"
      )

      {:ok, record}
    else
      err ->
        Logger.error(
          Utils.FromEnv.mfa_str(__ENV__) <>
            ": Error adding or updating record: err='#{err}' record=#{Utils.map_to_string(record)}"
        )

        {:error, err}
    end
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

    with {:ok, cf} <- CloudflareOps.delete_record(record) do
      Logger.info(
        Utils.FromEnv.mfa_str(__ENV__) <> ": Deleted record: cf=#{Utils.map_to_string(cf)}"
      )

      {:ok, record}
    else
      err ->
        Logger.error(
          Utils.FromEnv.mfa_str(__ENV__) <>
            ": Error deleting record: err='#{err}' record=#{Utils.map_to_string(record)}"
        )

        {:error, err}
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

    # Parse the cloudflarednsrecord into a DNS record
    {:ok, record} = parse(cloudflarednsrecord)

    with {:ok, cf} <- CloudflareOps.add_or_update_record(record) do
      Logger.info(
        Utils.FromEnv.mfa_str(__ENV__) <> ": Added or updated record: cf=#{Utils.map_to_string(cf)}"
      )

      {:ok, record}
    else
      err ->
        Logger.error(
          Utils.FromEnv.mfa_str(__ENV__) <>
            ": Error adding or updating record: err='#{err}' record=#{Utils.map_to_string(record)}"
        )

        {:error, err}
    end
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
  #       "namespace" => "malan-staging",
  #       "serviceName" => "Howdy",
  #       "hostName" => "malan-staging",
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
           "zoneId" => _zone_id
         }
       }) do
    Logger.debug(Utils.FromEnv.mfa_str(__ENV__) <> ": crd_to_cloudflare_record: (todo addme)")
  end

  defp parse(%{
         "metadata" => %{"name" => _name},
         "spec" => %{
           "namespace" => ns,
           "serviceName" => service_name,
           "hostName" => hostname,
           "domain" => domain,
           "zoneId" => zone_id
         }
       }) do
    Logger.debug(
      Utils.FromEnv.mfa_str(__ENV__) <>
        ": Parsing record: namespace='#{ns}' serviceName='#{service_name}' hostName='#{hostname}' domain='#{domain}' zoneId='#{zone_id}'"
    )

    with {:ok, hostname, domain} <- validate_hostname(hostname, domain),
         {:ok, service} <- get_service(ns, service_name),
         {:ok, ip} <- parse_svc_ip(service),
         {:ok, _} <- is_ipv4?(ip),
         {:ok, _} <- validate_domain(zone_id, domain),
         {:ok, cfar} <- assemble_cf_a_record(zone_id, hostname, domain, ip) do
      {:ok, cfar}
    else
      {:error, :not_found} -> nil
      {:error, :bad_ip} -> nil
      {:error, err} -> err
      err -> {:error, err}
    end
  end

  defp parse(record) do
    Logger.error(
      Utils.FromEnv.mfa_str(__ENV__) <>
        ": parse()/1 invoked with unhandled argument structure.  Make sure the cloudlfarednsrecord object you created in k8s has the expected structure:  #{Utils.map_to_string(record)}"
    )

    {:error, :unhandled_structure}
  end

  defp is_ipv4?(ip) do
    case Iptools.is_ipv4?(ip) do
      true -> {:ok, true}
      false -> {:err, :bad_ip}
    end
  end

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
    Logger.debug(
      Utils.FromEnv.mfa_str(__ENV__) <> ": parse_svc_ip: status='#{Utils.map_to_string(status)}'"
    )

    {:ok, ip}
  end

  defp assemble_cf_a_record(zone_id, hostname, domain, ip) do
    Logger.debug(
      Utils.FromEnv.mfa_str(__ENV__) <>
        ": assemble_cf_a_record: zone_id='#{zone_id}' hostname='#{hostname}' ip='#{ip}'"
    )

    cfar = %DnsRecord{
      zone_id: zone_id,
      hostname: hostname,
      zone_name: domain,
      # ip: List.first(service.status.loadBalancer.ingress).ip
      ip: ip
    }

    {:ok, cfar}
  end

  defp get_service(namespace, name) do
    svc = %{
      "apiVersion" => "v1",
      "kind" => "Service",
      "metadata" => %{
        "name" => name,
        "namespace" => namespace
      }
    }

    # New k8s version
    #with {:ok, conn} <- K8s.Conn.from_service_account(),
    #     operation <- K8s.Client.get(svc),
    #     {:ok, result} <- K8s.Client.run(conn, operation) do
    #  {:ok, result}

    Logger.debug(
      Utils.FromEnv.mfa_str(__ENV__) <>
        ":  Retrieving Service object from k8s: name='#{name}' namespace='#{namespace}'"
    )

    #with {:ok, conn} <- K8s.Conn.from_service_account(),
    with _conn <- K8s.Conn.from_file("~/.kube/ameelio-k8s-dev-kubeconfig.yaml"),
         operation <- K8s.Client.get(svc),
         #{:ok, result} <- K8s.Client.run(conn, operation) do
         {:ok, result} <- K8s.Client.run(operation, :default) do
      Logger.info(
        Utils.FromEnv.mfa_str(__ENV__) <>
          ": Retrieved Service object from k8s: #{Utils.map_to_string(result)}"
      )

      {:ok, result}
    else
      err ->
        Logger.error(
          Utils.FromEnv.mfa_str(__ENV__) <> ": Error retrieving Service object from k8s: #{err}"
        )

        {:error, err}
      # {:error, :not_found} -> 
        # The specified service doesn't exist!  Tell user about error somehow and stop
        # {:error, err}
      # {:error, err} -> {:error, err}
      # err -> {:error, err}
    end
  end

  defp validate_hostname(hostname, domain) do
    Logger.debug(Utils.FromEnv.mfa_str(__ENV__) <> ": hostname='#{hostname}'")

    cond do
      String.ends_with?(hostname, domain) ->
        Logger.debug(
          Utils.FromEnv.mfa_str(__ENV__) <>
            ": hostname='#{hostname}' ends with domain='#{domain}' already.  Not changing"
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
    Logger.debug(Utils.FromEnv.mfa_str(__ENV__) <> ": zone_id='#{zone_id}' domain='#{domain}'")
    # TODO: make sure that the `zone_name` for the `zone_id` matches `domain`
    {:ok, true}
  end
end
